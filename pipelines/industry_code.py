"""日本標準産業分類の取得。

e-Stat の統計分類・用語の検索で公開されている日本標準産業分類を、改定ごとに
CSV でダウンロードし、dbt が読み込める NDJSON に整形する。
令和5年7月・平成25年10月・平成19年11月・平成14年3月の4改定を収録する。

e-Stat API (getStatsData) には登録がないため、画面のダウンロードボタンと同じ
/term/download を直接叩く。pbCode を付けると指定コード直下の子だけが返るので、
付けずに空文字のキーワード検索として投げ、全階層を取る。

データソース: 政府統計の総合窓口(e-Stat) 統計分類・用語の検索 日本標準産業分類
https://www.e-stat.go.jp/classifications/terms/10
"""

import csv
import io
import json
import logging
import re
from pathlib import Path
from urllib.parse import urlencode

from pipelines.municipality_code import _fetch

logger = logging.getLogger("pipelines")

DOWNLOAD_URL = "https://www.e-stat.go.jp/term/download"

# e-Stat の改定番号 (kaiteiCode) と改定年
REVISIONS = {
    "04": 2023,  # 令和5年7月改定（第14回）
    "03": 2013,  # 平成25年10月改定（第13回）
    "02": 2007,  # 平成19年11月改定（第12回）
    "01": 2002,  # 平成14年3月改定（第11回）
}

# コードの書式で階層が決まる。大分類は英字1文字、以下は数字の桁数
_LEVELS = [
    (re.compile(r"^[A-Z]$"), "major"),
    (re.compile(r"^\d{2}$"), "middle"),
    (re.compile(r"^\d{3}$"), "minor"),
    (re.compile(r"^\d{4}$"), "detail"),
]


def _download_params(kaitei_code: str) -> dict[str, str]:
    return {
        "bKbn": "10",
        "kaiteiCode": kaitei_code,
        "charset": "UTF-8",
        "bom": "0",
        "searchMethod": "keyword",
        "searchWord": "",
        "komokuSearchFlg": "1",
        "info1SearchFlg": "1",
        "info2SearchFlg": "1",
        "info3SearchFlg": "",
        "info4SearchFlg": "",
        "info5SearchFlg": "",
        "info6SearchFlg": "",
    }


def _level(code: str) -> str:
    for pattern, level in _LEVELS:
        if pattern.match(code):
            return level
    raise SystemExit(f"産業分類コードの書式が想定外: {code!r}")


def _clean(value: str) -> str | None:
    s = value.replace("\r\n", "\n").strip()
    return s or None


def _parse(text: str, revision: int) -> list[dict]:
    """1改定分の CSV を整形する。

    1行目はタイトル、2行目がヘッダー（分類コード, 項目名, 項目の説明, 事例,
    不適合事例）、3行目はコードが全角スペースの注記行。説明欄がセル内で改行
    するため、引用符を解釈して読む。

    中分類の親（大分類）はコードから導けないので、大分類の直後にその中分類以下が
    並ぶ並び順から取る。小分類・細分類の親はコードの先頭を切って求める。
    """
    rows = list(csv.reader(io.StringIO(text)))
    header = rows[1] if len(rows) > 1 else rows
    if header[:2] != ["分類コード", "項目名"]:
        raise SystemExit(f"{revision} 年改定の産業分類 CSV のヘッダーが想定外: {header}")

    records = []
    major = None
    for r in rows[2:]:
        if not r:
            continue  # 空行
        # 令和5年・平成25年版の細分類 2425 はコードの引用符の中に改行が入って
        # 崩れている（'\r\n2425"'）。改行と引用符を落として読む。
        code = re.sub(r'[\r\n"]', "", r[0]).strip()
        if not code:
            continue  # 注記行（コードが全角スペース）
        if len(r) < 5:
            raise SystemExit(f"{revision} 年改定の {code} の列が足りない: {r}")
        level = _level(code)
        if level == "major":
            major = code
            parent = None
        elif level == "middle":
            if major is None:
                raise SystemExit(f"大分類より前に中分類がある: {code}")
            parent = major
        else:
            parent = code[:-1]
        records.append(
            {
                "revision": revision,
                "level": level,
                "code": code,
                "name": _clean(r[1]),
                "parent_code": parent,
                "major_code": major,
                "description": _clean(r[2]),
                "examples": _clean(r[3]),
                "non_examples": _clean(r[4]),
            }
        )

    codes = {rec["code"] for rec in records}
    if len(codes) != len(records):
        raise SystemExit(f"{revision} 年改定でコードが重複している")
    orphans = [
        rec["code"]
        for rec in records
        if rec["parent_code"] and rec["parent_code"] not in codes
    ]
    if orphans:
        raise SystemExit(f"{revision} 年改定で親の無いコード: {orphans[:10]}")
    return records


def build_industry_code(dest_dir: str) -> None:
    """日本標準産業分類の4改定を取得し NDJSON に整形する。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)

    records = []
    for kaitei_code, revision in REVISIONS.items():
        url = f"{DOWNLOAD_URL}?{urlencode(_download_params(kaitei_code))}"
        logger.info(f"  downloading {revision} revision")
        raw = _fetch(url)
        (dest / f"industry_{revision}.csv").write_bytes(raw)
        parsed = _parse(raw.decode("utf-8"), revision)
        logger.info(f"  {revision}: {len(parsed)} rows")
        records.extend(parsed)

    with (dest / "industry.ndjson").open("w", encoding="utf-8") as f:
        for rec in records:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
