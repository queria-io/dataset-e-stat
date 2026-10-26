"""介護保険事業状況報告 (年報) の保険者別の表の取得 (getDataCatalog + 統計表 Excel)。

介護保険の保険者 (市区町村と、複数の市町村でつくる広域連合・一部事務組合) ごとに、
年度末現在の第1号被保険者数と要介護 (要支援) 認定者数を取る。2001 年度から毎年度。

■ 取り込み方

数年に 1 度ではないが年に 1 度しか出ず、過去の年度も直らないので、CI の Sync では
取らない。load_local.py の kaigo_insurance グループとして手元で 1 回取り、公開する。
更新は scripts/check_local_updates.py が getDataCatalog の更新日で見張る。

■ getStatsData を使わない理由

この統計は e-Stat のデータベースに 1 表も登録が無く (getStatsList で 0 件)、
提供は統計表ファイル (Excel) だけ。kaigo_service と同じく getDataCatalog から辿る。

■ 取り込む表

年度ごとに 1 ファイルずつ。表題は年度で変わる。
- 第1号被保険者数: 「2-2_都道府県別第１号被保険者数（保険者別）」(2001〜2005 年度)、
  「02H_保険者別第１号被保険者数」(2006〜2009)、「02h_<保険者別>第１号被保険者数」(2010〜)
- 要介護 (要支援) 認定者数: 「4-2_…認定者数（当年度末現在）（保険者別）」(2001〜2005)、
  「04H_…」(2006〜2009)、「04h_…」(2010〜2013)、「04-1h_…男女計」(2014)、
  「04-1-1h_…男女計 - 総数 -」(2015〜)。2014 年度からは男・女の表も別にあるが、男女計だけ取る

2000 年度は保険者別の表が無い (都道府県別だけ)。

■ 表の形

行は全国 1 行と保険者。都道府県の小計の行は無い。保険者番号は無く、都道府県名と
保険者名だけが並ぶ。市区町村コードへの当てはめは dbt 側で名前で行う。2005 年度まで
と 2006〜2009 年度は先頭に行番号の列が付く。列の位置は年度で変わるので、「都道府県」
の見出しのセルを探して、その右を保険者名、さらに右を値の列とする。

列見出しは 2〜3 行に重なる (被保険者の区分 → 年齢 → 要介護度)。空欄は、上の段が
同じ範囲でだけ左から送る。2009 年度までは表が 1 シートに横に並び、2010 年度からは
被保険者の区分ごとにシートが分かれる。どちらも同じ手順で読める。

第1号被保険者数の表は 2009 年度まで「前年度末現在・当年度中増・当年度中減・
当年度末現在」の 4 列ずつ並ぶ。当年度末現在だけを取る。

要介護度の区分は制度改正で変わる。2005 年度までは要支援・要介護1〜5、2006〜2009 年度
は要支援1・2・経過的要介護・要介護1〜5 (「計」が要支援と要介護の小計で 2 回、最後に
「合計」)、2010 年度からは要支援1・2・要介護1〜5・合計。小計は足し算で出せるので取らない。

■ 値

「-」は該当なし (0 人) として 0 にする。空欄は NULL。2001 年度は 2 保険者が公表を
見合わせていて表に無い。負の値が少しある (2013 年度の「-2」など)。原典の注のとおり、
受給者台帳の提出後に要介護度が遡って変わった分の差し引きで、そのまま持つ。

データソース: 厚生労働省 介護保険事業状況報告
https://www.e-stat.go.jp/stat-search/files?toukei=00450351
"""

import io
import json
import logging
import re
import time
import unicodedata
import urllib.parse
from http.client import IncompleteRead
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

from pipelines import EstatStatus, check_latest_year

logger = logging.getLogger("pipelines")

CATALOG_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getDataCatalog"
STATS_CODE = "00450351"
_UA = "dataset-e-stat"
_TIMEOUT = 300
# kaigo_service と同じ理由。統計表ファイルの配信は、存在する URL にも 404 を返す窓を持つ。
_TRANSIENT_HTTP_CODES = {404, 500, 502, 503, 504}
_MAX_RETRIES = 8
_MAX_WAIT = 30
_MAX_NETWORK_RETRIES = 4
PAGE_LIMIT = 100

# 保険者別の表が出る最初の年度。2000 年度は都道府県別だけ。
FIRST_FISCAL_YEAR = 2001
# N 年度の年報は N+2 年の 8 月に出る (令和6年度は 2026-08-27)。
LATEST_LAG_YEARS = 2

INSURED_TITLE_RE = re.compile(r"保険者別.*第[１1]号被保険者数|第[１1]号被保険者数.*保険者別")
CERTIFIED_TITLE_RE = re.compile(r"保険者別.*認定者数|認定者数.*保険者別")
# 同じ語を含むが取らない表。2014 年度からの男・女別の表は「認定者数　男 - 総数 -」の形。
EXCLUDED_TITLE_RE = re.compile(r"所得段階|増減|世帯数|負担対象|認定者数\s*[男女](\s|-|$)")

PREFECTURES = (
    "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県", "茨城県",
    "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県", "新潟県", "富山県",
    "石川県", "福井県", "山梨県", "長野県", "岐阜県", "静岡県", "愛知県", "三重県",
    "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県", "鳥取県", "島根県",
    "岡山県", "広島県", "山口県", "徳島県", "香川県", "愛媛県", "高知県", "福岡県",
    "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県",
)  # fmt: skip
NATIONWIDE_LABELS = {"全国", "全国計"}
NATIONWIDE = "全国"

# 第1号被保険者数の列。2009 年度までの前年度末・当年度中の増減の列は外す。
INSURED_CATEGORIES = {
    "計",
    "65歳以上75歳未満",
    "75歳以上",
    "75歳以上85歳未満",
    "85歳以上",
    "外国人被保険者(再掲)",
    "住所地特例被保険者(再掲)",
}
INSURED_SKIP_RE = re.compile(r"前年度末|当年度中")

INSURED_GROUP_RE = re.compile(r"^(総数|第1号被保険者|第2号被保険者)(.*)$")
CARE_LEVELS = {
    "要支援",
    "要支援1",
    "要支援2",
    "経過的要介護",
    "要介護1",
    "要介護2",
    "要介護3",
    "要介護4",
    "要介護5",
    "合計",
}
# 原典で該当が無いセル。介護保険事業状況報告ではどれも 0 人の意味で使われる。
ZERO_VALUES = {"-", "―", "‐", "−"}
NUMBER_RE = re.compile(r"^-?\d+(\.0)?$")


def _fetch(url: str) -> bytes:
    """再試行付きで URL を取得する。"""
    for attempt in range(_MAX_RETRIES):
        try:
            req = Request(url, headers={"User-Agent": _UA})
            with urlopen(req, timeout=_TIMEOUT) as resp:
                return resp.read()
        except (
            HTTPError,
            URLError,
            TimeoutError,
            ConnectionResetError,
            IncompleteRead,
        ) as e:
            if isinstance(e, HTTPError):
                transient = e.code in _TRANSIENT_HTTP_CODES
                limit = _MAX_RETRIES
            else:
                transient = True
                limit = _MAX_NETWORK_RETRIES
            if not transient or attempt == limit - 1:
                raise
            wait = min(2**attempt, _MAX_WAIT)
            reason = getattr(e, "reason", None) or getattr(e, "code", None) or e
            logger.warning(f"  {reason}, retry in {wait}s ({attempt + 1}/{limit})")
            time.sleep(wait)
    raise RuntimeError("unreachable")


def _norm(cell) -> str:
    """全角英数・全角空白を畳み、空白と改行を除く。"""
    if cell is None or (isinstance(cell, float) and pd.isna(cell)):
        return ""
    s = unicodedata.normalize("NFKC", str(cell))
    return re.sub(r"\s", "", s)


def catalog_resources(app_id: str) -> list[dict]:
    """統計表ファイルの一覧を集める。"""
    resources: list[dict] = []
    start_position = 1
    while True:
        params = urllib.parse.urlencode(
            {
                "appId": app_id,
                "statsCode": STATS_CODE,
                "limit": PAGE_LIMIT,
                "startPosition": start_position,
            }
        )
        root = json.loads(_fetch(f"{CATALOG_URL}?{params}"))["GET_DATA_CATALOG"]
        status = root["RESULT"]["STATUS"]
        if status not in (EstatStatus.OK, EstatStatus.PARTIAL):
            error = root["RESULT"].get("ERROR_MSG", "")
            raise RuntimeError(f"getDataCatalog: API error (status {status}): {error}")

        listing = root["DATA_CATALOG_LIST_INF"]
        items = listing["DATA_CATALOG_INF"]
        if isinstance(items, dict):
            items = [items]
        for item in items:
            survey_date = item["DATASET"]["TITLE"]["SURVEY_DATE"]
            item_resources = item["RESOURCES"]["RESOURCE"]
            if isinstance(item_resources, dict):
                item_resources = [item_resources]
            for res in item_resources:
                resources.append(
                    {
                        # SURVEY_DATE は「202404-202503」のような年度の範囲
                        "fiscal_year": int(survey_date[:4]),
                        "title": res["TITLE"]["NAME"],
                        "format": res["FORMAT"],
                        "url": res["URL"],
                        "last_modified_date": res["LAST_MODIFIED_DATE"],
                    }
                )

        next_key = listing.get("RESULT_INF", {}).get("NEXT_KEY")
        if not next_key:
            break
        if int(next_key) <= start_position:
            raise RuntimeError(
                f"getDataCatalog: NEXT_KEY {next_key} が "
                f"startPosition {start_position} から進まない"
            )
        start_position = int(next_key)

    if not resources:
        raise RuntimeError(f"getDataCatalog に {STATS_CODE} の統計表ファイルが無い")
    return resources


def catalog_modified_date(resources: list[dict]) -> str:
    """統計全体の最終更新日。新しい年度が出ても、過去の表が直っても進む。

    scripts/check_local_updates.py が同じ定義で見張る。
    """
    return max(r["last_modified_date"] for r in resources)


def catalog(resources: list[dict]) -> list[tuple[int, str, str]]:
    """取り込む表の所在を (年度, 表, URL) で集める。表は insured / certified。"""
    found: dict[tuple[int, str], str] = {}
    for res in resources:
        title = res["title"]
        if res["fiscal_year"] < FIRST_FISCAL_YEAR or not res["format"].startswith("XLS"):
            continue
        if EXCLUDED_TITLE_RE.search(title):
            continue
        if INSURED_TITLE_RE.search(title):
            table = "insured"
        elif CERTIFIED_TITLE_RE.search(title):
            table = "certified"
        else:
            continue
        key = (res["fiscal_year"], table)
        if key in found:
            raise RuntimeError(f"{res['fiscal_year']}年度の {table} に表が 2 つある: {title}")
        found[key] = res["url"]

    # 表題が変わって 1 年度だけ落ちても、ほかの年度はそのまま残るので気づけない。
    # 年度の連続と、両方の表がそろうことをここで押さえる。
    years = sorted({year for year, _ in found})
    if not years:
        raise RuntimeError("保険者別の表が見つからない")
    check_latest_year(years[-1], LATEST_LAG_YEARS)
    if missing := [
        f"{year} {table}"
        for year in range(FIRST_FISCAL_YEAR, years[-1] + 1)
        for table in ("insured", "certified")
        if (year, table) not in found
    ]:
        raise RuntimeError(f"表が欠けている: {missing}")
    return sorted((year, table, url) for (year, table), url in found.items())


def _read_sheets(body: bytes) -> list[tuple[str, pd.DataFrame]]:
    engine = "openpyxl" if body[:2] == b"PK" else "xlrd"
    sheets = pd.read_excel(io.BytesIO(body), engine=engine, header=None, dtype=str, sheet_name=None)
    return list(sheets.items())


def _layout(df: pd.DataFrame, where: str) -> tuple[int, int, int]:
    """(見出しの先頭行, 都道府県の列, データの先頭行) を返す。"""
    cells = df.map(_norm)
    hits = [(r, c) for r, c in zip(*(cells == "都道府県").to_numpy().nonzero(), strict=True)]
    if len(hits) != 1:
        raise RuntimeError(f"{where}: 「都道府県」の見出しが {len(hits)} 個")
    top, pref_col = (int(v) for v in hits[0])
    if "保険者" not in cells.iat[top, pref_col + 1]:
        raise RuntimeError(f"{where}: 都道府県の右が保険者の列ではない")
    labels = set(PREFECTURES) | NATIONWIDE_LABELS
    start = next(
        (r for r in range(top + 1, len(df)) if cells.iat[r, pref_col] in labels),
        None,
    )
    if start is None:
        raise RuntimeError(f"{where}: データの行が無い")
    return top, pref_col, start


def _column_labels(df: pd.DataFrame, header_rows: range, first_col: int) -> list[list[str]]:
    """値の列ごとに、見出しを上から並べたものを返す。

    空欄は、上の段が左の列と同じときだけ左から送る。上の段の範囲をまたいで送ると、
    「75歳以上」が右隣の第2号被保険者の列まで伸びる。
    """
    width = df.shape[1]
    filled: list[list[str]] = []
    for r in header_rows:
        row = [_norm(df.iat[r, c]) for c in range(first_col, width)]
        for j in range(1, len(row)):
            if not row[j] and all(f[j] == f[j - 1] for f in filled):
                row[j] = row[j - 1]
        filled.append(row)
    labels = []
    for j in range(width - first_col):
        parts: list[str] = []
        for f in filled:
            if f[j] and (not parts or parts[-1] != f[j]):
                parts.append(f[j])
        labels.append(parts)
    return labels


def _value(cell, where: str) -> int | None:
    s = _norm(cell).replace(",", "")
    if not s:
        return None
    if s in ZERO_VALUES:
        return 0
    if not NUMBER_RE.match(s):
        raise RuntimeError(f"{where}: 数値として読めないセル {cell!r}")
    return int(float(s))


def _rows(df: pd.DataFrame, pref_col: int, start: int, where: str):
    """(都道府県名, 保険者名, 行) を返す。全国の行は ('全国', None, 行)。"""
    nationwide = 0
    insurers: set[tuple[str, str]] = set()
    for r in range(start, len(df)):
        pref = _norm(df.iat[r, pref_col])
        name = _norm(df.iat[r, pref_col + 1])
        if pref in NATIONWIDE_LABELS:
            nationwide += 1
            yield NATIONWIDE, None, r
        elif pref in PREFECTURES:
            if not name:
                raise RuntimeError(f"{where}: {r} 行目に保険者名が無い")
            if (pref, name) in insurers:
                raise RuntimeError(f"{where}: {pref} {name} が 2 行ある")
            insurers.add((pref, name))
            yield pref, name, r
        elif pref or name:
            # 表の下の注。保険者の行より後にしか出ない
            continue
    if nationwide > 1:
        raise RuntimeError(f"{where}: 全国の行が {nationwide} 行")
    if len({p for p, _ in insurers}) != len(PREFECTURES):
        raise RuntimeError(f"{where}: 保険者のいる都道府県が {len({p for p, _ in insurers})}")


def parse_insured(body: bytes, fiscal_year: int) -> list[dict]:
    """第1号被保険者数の表を 1 セル 1 行にする。"""
    sheets = _read_sheets(body)
    if len(sheets) != 1:
        raise RuntimeError(f"{fiscal_year}年度 第1号被保険者数: シートが {len(sheets)} 枚")
    _, df = sheets[0]
    where = f"{fiscal_year}年度 第1号被保険者数"
    top, pref_col, start = _layout(df, where)
    labels = _column_labels(df, range(top, start), pref_col + 2)

    columns: dict[int, str] = {}
    for j, parts in enumerate(labels):
        if not parts or any(INSURED_SKIP_RE.search(p) for p in parts):
            continue
        # 「計」は 2010 年度から年齢の列の上にも掛かる。年齢の見出しがあればそちら
        rest = [p for p in parts if p != "計" and not p.startswith("当年度末")]
        category = rest[-1] if rest else "計"
        # 2010 年度からは「(再掲)」が見出しから落ちる。内数なのは変わらない
        if category in ("外国人被保険者", "住所地特例被保険者"):
            category += "(再掲)"
        if category not in INSURED_CATEGORIES:
            raise RuntimeError(f"{where}: 知らない列見出し {parts}")
        columns[pref_col + 2 + j] = category
    if "計" not in columns.values() or len(set(columns.values())) != len(columns):
        raise RuntimeError(f"{where}: 列の当てはめがおかしい {columns}")

    return [
        {
            "fiscal_year": fiscal_year,
            "prefecture_name": pref,
            "insurer_name": name,
            "category": category,
            "value": _value(df.iat[r, c], f"{where} {r}行{c}列"),
        }
        for pref, name, r in _rows(df, pref_col, start, where)
        for c, category in columns.items()
    ]


def _care_levels(parts_by_col: list[tuple[int, str, str]], where: str) -> dict[int, tuple[str, str]]:
    """(列, 被保険者の区分, 見出しの末尾) から、要介護度を決める。

    「計」は 2005 年度までは合計、2006〜2009 年度は要支援と要介護の小計 (合計は
    「合計」)。小計の列は外す。
    """
    by_group: dict[str, list[tuple[int, str]]] = {}
    for col, group, level in parts_by_col:
        by_group.setdefault(group, []).append((col, level))
    result: dict[int, tuple[str, str]] = {}
    for group, cols in by_group.items():
        has_grand_total = any(level == "合計" for _, level in cols)
        for col, level in cols:
            if level == "計":
                if has_grand_total:
                    continue
                level = "合計"
            if level not in CARE_LEVELS:
                raise RuntimeError(f"{where}: {group} に知らない要介護度 {level!r}")
            result[col] = (group, level)
        levels = [level for g, level in result.values() if g == group]
        if levels.count("合計") != 1 or len(set(levels)) != len(levels):
            raise RuntimeError(f"{where}: {group} の要介護度の並びがおかしい {levels}")
    return result


def _group(parts: list[str], where: str) -> tuple[str, str | None]:
    text = "".join(parts).replace("(再掲)", "").replace("-", "")
    m = INSURED_GROUP_RE.match(text)
    if not m:
        raise RuntimeError(f"{where}: 被保険者の区分を読めない {parts}")
    return m.group(1), (m.group(2) or None)


def parse_certified(body: bytes, fiscal_year: int) -> list[dict]:
    """要介護 (要支援) 認定者数の表を 1 セル 1 行にする。"""
    records: list[dict] = []
    seen: set[tuple[str, str | None]] = set()
    for sheet, df in _read_sheets(body):
        where = f"{fiscal_year}年度 認定者数 {sheet}"
        top, pref_col, start = _layout(df, where)
        labels = _column_labels(df, range(top, start), pref_col + 2)
        parts_by_col = []
        for j, parts in enumerate(labels):
            if not parts:
                continue
            if len(parts) < 2:
                raise RuntimeError(f"{where}: 被保険者の区分が無い列 {parts}")
            category, age_group = _group(parts[:-1], where)
            parts_by_col.append((pref_col + 2 + j, f"{category}|{age_group or ''}", parts[-1]))
        columns = _care_levels(parts_by_col, where)
        groups = {g for g, _ in columns.values()}
        if overlap := groups & {f"{c}|{a or ''}" for c, a in seen}:
            raise RuntimeError(f"{where}: 区分 {overlap} がほかのシートにもある")
        seen |= {(g.split("|")[0], g.split("|")[1] or None) for g in groups}
        for pref, name, r in _rows(df, pref_col, start, where):
            for c, (group, level) in columns.items():
                category, age_group = group.split("|")
                records.append(
                    {
                        "fiscal_year": fiscal_year,
                        "prefecture_name": pref,
                        "insurer_name": name,
                        "insured_category": category,
                        "age_group": age_group or None,
                        "care_level": level,
                        "value": _value(df.iat[r, c], f"{where} {r}行{c}列"),
                    }
                )
    if ("総数", None) not in seen:
        raise RuntimeError(f"{fiscal_year}年度 認定者数: 総数の列が無い")
    return records


INSURED_SCHEMA = pa.schema(
    [
        ("fiscal_year", pa.int32()),
        ("prefecture_name", pa.string()),
        ("insurer_name", pa.string()),
        ("category", pa.string()),
        ("value", pa.int64()),
    ]
)
CERTIFIED_SCHEMA = pa.schema(
    [
        ("fiscal_year", pa.int32()),
        ("prefecture_name", pa.string()),
        ("insurer_name", pa.string()),
        ("insured_category", pa.string()),
        ("age_group", pa.string()),
        ("care_level", pa.string()),
        ("value", pa.int64()),
    ]
)
# local_tables.yml の表の名前 → (catalog の表, パーサ, スキーマ)
TABLES = {
    "kaigo_insurance_insured": ("insured", parse_insured, INSURED_SCHEMA),
    "kaigo_insurance_certified": ("certified", parse_certified, CERTIFIED_SCHEMA),
}


def fetch_local(app_id: str, spec: dict, cache_path) -> None:
    """load_local.py の fetch。統計表を取り、表ごとに cache_path(表) の Parquet を書く。

    取得した Excel は Parquet と同じ場所の files/ に残し、次の回はそこから読む。
    """
    resources = catalog_resources(app_id)
    modified = catalog_modified_date(resources)
    if modified != str(spec["catalog_modified_date"]):
        raise SystemExit(
            f"e-Stat の最終更新日 {modified} が local_tables.yml の "
            f"{spec['catalog_modified_date']} と違う。yml を直してから取り直す"
        )
    entries = catalog(resources)

    for table in spec["tables"]:
        name = table["name"]
        out = cache_path(table)
        if out.exists():
            logger.info(f"  {name}: 取得済み")
            continue
        files = out.parent / "files" / modified
        files.mkdir(parents=True, exist_ok=True)
        kind, parse, schema = TABLES[name]
        records: list[dict] = []
        for fiscal_year, entry_kind, url in entries:
            if entry_kind != kind:
                continue
            path = files / f"{fiscal_year}_{kind}.xls"
            if not path.exists():
                path.write_bytes(_fetch(url))
            parsed = parse(path.read_bytes(), fiscal_year)
            logger.info(f"  {name} {fiscal_year}年度: {len(parsed)} 行")
            records += parsed
        tmp = out.with_suffix(".parquet.tmp")
        pq.write_table(pa.Table.from_pylist(records, schema=schema), tmp)
        tmp.rename(out)
        logger.info(f"  {name}: {len(records)} 行")
