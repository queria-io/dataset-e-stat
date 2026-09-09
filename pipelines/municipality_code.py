"""統計に用いる標準地域コードの取得。

総務省統計局の「統計に用いる標準地域コード」ページから、現行のコード一覧
(全国 CSV) と平成19年4月2日以降のコード変更 (廃置分合) 履歴 (Excel) を取得し、
dbt が読み込める NDJSON に整形する。

e-Stat API は経由しない (このデータは統計データではなく地域コードの基準表で、
getStatsData には登録がない)。ページの掲載ファイルを直接ダウンロードする。

データソース: 総務省統計局 統計に用いる標準地域コード
https://www.soumu.go.jp/toukei_toukatsu/index/seido/9-5.htm
"""

import json
import logging
import re
import time
from http.client import IncompleteRead
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin
from urllib.request import Request, urlopen

import pandas as pd

logger = logging.getLogger("pipelines")

INDEX_URL = "https://www.soumu.go.jp/toukei_toukatsu/index/seido/9-5.htm"
_UA = "dataset-e-stat"
_TIMEOUT = 60
_MAX_RETRIES = 4
_TRANSIENT_HTTP_CODES = {500, 502, 503, 504}


def _fetch(url: str) -> bytes:
    """再試行付きで URL を取得する。総務省サイトは混雑時に一時エラーを返す。"""
    for attempt in range(_MAX_RETRIES):
        try:
            req = Request(url, headers={"User-Agent": _UA})
            with urlopen(req, timeout=_TIMEOUT) as resp:
                return resp.read()
        # 応答の読み取り中に起きる失敗は URLError に包まれない。urllib が包むのは
        # 送信時の OSError だけで、getresponse() 以降はソケット層の
        # TimeoutError / ConnectionResetError と、本文が Content-Length に届かない
        # IncompleteRead がそのまま上がる。明示しないと再試行を素通りする。
        except (
            HTTPError,
            URLError,
            TimeoutError,
            ConnectionResetError,
            IncompleteRead,
        ) as e:
            transient = not isinstance(e, HTTPError) or e.code in _TRANSIENT_HTTP_CODES
            if not transient or attempt == _MAX_RETRIES - 1:
                raise
            wait = 2**attempt
            reason = getattr(e, "reason", None) or getattr(e, "code", None) or e
            logger.warning(f"  {reason}, retry in {wait}s ({attempt + 1}/{_MAX_RETRIES})")
            time.sleep(wait)
    raise RuntimeError("unreachable")


def _resolve_links() -> tuple[str, str]:
    """掲載ページを解析し、現行コード CSV と変更履歴 Excel の URL を求める。

    ファイル ID (main_content/000323625.csv 等) は改正のたびに変わるため、URL を
    ハードコードせずページから解決する。ページには CSV・Excel が各1件だけ載る。
    """
    html = _fetch(INDEX_URL).decode("shift_jis", errors="replace")
    hrefs = re.findall(r'href="([^"]+)"', html)
    csvs = [urljoin(INDEX_URL, h) for h in hrefs if h.lower().endswith(".csv")]
    xlss = [urljoin(INDEX_URL, h) for h in hrefs if h.lower().endswith((".xls", ".xlsx"))]
    if len(csvs) != 1 or len(xlss) != 1:
        raise SystemExit(
            "unexpected file links on soumu page "
            f"(csv={len(csvs)}, excel={len(xlss)}); ページ構成が変わった可能性がある"
        )
    return csvs[0], xlss[0]


def _split_code_name(cell: object) -> tuple[str | None, str | None]:
    """'309　飯野町' -> ('309', '飯野町')。空セル ('　') -> (None, None)。

    先頭の数字を 3 桁の市区町村コード、残りを名称 (削除 / 新市名等) として分割する。
    """
    if cell is None or (isinstance(cell, float) and pd.isna(cell)):
        return None, None
    s = str(cell).replace("　", " ").strip()
    if not s:
        return None, None
    m = re.match(r"^(\d+)\s*(.*)$", s)
    if not m:
        return None, s or None
    return m.group(1), (m.group(2).strip() or None)


def _parse_municipality(csv_path: Path) -> list[dict]:
    """現行の標準地域コード一覧 (全国 CSV, Shift-JIS) を整形する。

    列: ken-code, sityouson-code, tiiki-code, ken-name,
        sityouson-name1(郡・振興局・政令市), sityouson-name2(未使用),
        sityouson-name3(市区町村), yomigana。
    """
    df = pd.read_csv(csv_path, dtype=str, encoding="shift_jis")
    records = []
    for _, r in df.iterrows():
        records.append(
            {
                "area_code": r["tiiki-code"],
                "pref_code": r["ken-code"],
                "pref_name": r["ken-name"],
                "district_name": _clean(r.get("sityouson-name1")),
                "municipality_name": _clean(r.get("sityouson-name3")),
                "yomigana": _clean(r.get("yomigana")),
                "is_prefecture": r["sityouson-code"] == "000",
            }
        )
    return records


def _parse_changes(xls_path: Path, name_to_pref_code: dict[str, str]) -> list[dict]:
    """平成19年4月2日以降のコード変更 (廃置分合) 履歴を整形する。

    1 つの改正 (合併・編入等) は、都道府県・改正事由・施行年月日を先頭行にだけ
    記載し、影響を受ける各市区町村を 1 行ずつ列挙する (よみがな行が各行の直後に
    続く)。都道府県・事由・年月日を下方向に補完し、新コード欄に数字を含む行のみを
    1 レコードとして取り出す。
    """
    df = pd.read_excel(xls_path, engine="xlrd", header=None, dtype=str)
    header_rows = df.index[df[0] == "都道府県"]
    if len(header_rows) == 0:
        raise SystemExit("変更履歴 Excel に見出し行 (都道府県) が見つからない")
    body = df.loc[header_rows[0] + 1 :]

    records = []
    cur_pref = cur_reason = cur_date = None
    unmapped: set[str] = set()
    for _, r in body.iterrows():
        c0, c1, c2, c3, c4 = (_clean(r[k]) for k in range(5))
        if c0:
            cur_pref = c0
        if c4:
            cur_date = str(c4)[:10]
        if c3:
            cur_reason = c3
        # 新コード欄に数字を含む行だけがレコード。よみがな行・空行は除く。
        if not (c2 and re.search(r"\d", c2)):
            continue
        pref_code = name_to_pref_code.get(cur_pref or "")
        if pref_code is None:
            unmapped.add(cur_pref or "")
            continue
        old_code, old_name = _split_code_name(c1)
        new_code, new_name = _split_code_name(c2)
        records.append(
            {
                "effective_date": cur_date,
                "pref_code": pref_code,
                "pref_name": cur_pref,
                "old_code": (pref_code + old_code) if old_code else None,
                "old_name": old_name,
                "new_code": (pref_code + new_code) if new_code else None,
                "new_name": new_name,
                "is_code_deleted": bool(new_name and new_name.startswith("削除")),
                "reason": cur_reason,
            }
        )
    if unmapped:
        raise SystemExit(f"都道府県名をコードに変換できない: {sorted(unmapped)}")
    return records


def _clean(value: object) -> str | None:
    if value is None or (isinstance(value, float) and pd.isna(value)):
        return None
    s = str(value).replace("　", " ").strip()
    return s or None


def _write_ndjson(records: list[dict], path: Path) -> None:
    with path.open("w", encoding="utf-8") as f:
        for rec in records:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")


def build_municipality_code(dest_dir: str) -> None:
    """標準地域コード一覧と廃置分合履歴を取得し NDJSON に整形する。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)

    csv_url, xls_url = _resolve_links()
    csv_path = dest / "municipality_code.csv"
    xls_path = dest / "municipality_change.xls"
    logger.info(f"  downloading {csv_url}")
    csv_path.write_bytes(_fetch(csv_url))
    logger.info(f"  downloading {xls_url}")
    xls_path.write_bytes(_fetch(xls_url))

    municipality = _parse_municipality(csv_path)
    name_to_pref_code = {
        r["pref_name"]: r["pref_code"] for r in municipality if r["is_prefecture"]
    }
    changes = _parse_changes(xls_path, name_to_pref_code)

    _write_ndjson(municipality, dest / "municipality.ndjson")
    _write_ndjson(changes, dest / "municipality_change.ndjson")
    logger.info(
        f"  municipality={len(municipality)} rows, "
        f"municipality_change={len(changes)} rows"
    )
