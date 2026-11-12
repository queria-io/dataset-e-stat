"""一般職業紹介状況（職業安定業務統計）の都道府県別の表 (getDataCatalog + 統計表 Excel)。

厚生労働省の一般職業紹介状況のうち、ハローワークの求人数・求職者数・求人倍率を都道府県別に取る。
受理地別は1963年1月から、就業地別は2005年2月 (年・年度の平均は2006年) から。

■ 取り込み方

e-Stat のデータベースに表は無く、統計表ファイル (Excel) で配られる。「長期時系列表」に全期間を
1 ファイルにまとめた Excel があり、毎月の公表で差し替わる (季節調整値は毎年1月分の公表で過去の月も
改定される)。2 ファイルで約 4MB なので、毎日の Sync で取り直して置き換える。

■ 取り込む表

- 第11表 都道府県（受理地）別 労働市場関係指標（実数、季節調整値）: 新規求人数・新規求職申込件数・
  有効求人数・有効求職者数・新規求人倍率・有効求人倍率の 6 指標 × 実数・季節調整値の 12 シート
- 第18表 都道府県（就業地）別 労働市場関係指標（実数、季節調整値）: 新規求人数・有効求人数・
  新規求人倍率・有効求人倍率の 4 指標 × 実数・季節調整値の 8 シート。求職者は受理地でしか数えない

受理地は求人・求職を受け付けたハローワークの所在地、就業地は求人の働く場所。本社が一括して出す
求人は、受理地別では本社の都道府県に数える。

■ シートの形

1 行目が表題、2 行目が見出し (西暦・和暦・月・全国・北海道…沖縄県)、3 行目が単位、4 行目から値。
行は「1963年」(年平均)・「1963年度」(年度平均)・「1963年」「１月」(月) の 3 種類で、月の列が空なら
年か年度。実数のシートだけが年・年度の行を持つ。第18表に全国の列は無い。末尾に注の行がある。

データソース: 厚生労働省 一般職業紹介状況（職業安定業務統計）
https://www.e-stat.go.jp/stat-search/files?toukei=00450222
"""

import io
import json
import logging
import re
import unicodedata
import urllib.parse
from datetime import date
from pathlib import Path

import openpyxl
import pyarrow as pa
import pyarrow.parquet as pq

from pipelines import EstatStatus
from pipelines.commerce import _fetch
from pipelines.energy_consumption import PREFECTURES

logger = logging.getLogger("pipelines")

CATALOG_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getDataCatalog"
STATS_CODE = "00450222"
SEARCH_WORD = "労働市場関係指標"
PAGE_LIMIT = 100
EXCEL_FORMATS = ("XLS", "XLSX", "XLS_REP")

# 表 → (統計表ファイルの名前, 最初の月)
TABLES = {
    "acceptance": ("都道府県（受理地）別労働市場関係指標（実数、季節調整値）", (1963, 1)),
    "workplace": ("都道府県（就業地）別労働市場関係指標（実数、季節調整値）", (2005, 2)),
}
BASIS_NAMES = {"acceptance": "受理地", "workplace": "就業地"}

# シート名の指標 → 列名
MEASURES = {
    "新規求人数": "new_job_openings",
    "新規求職申込件数": "new_applications",
    "有効求人数": "active_job_openings",
    "有効求職者数": "active_applicants",
    "新規求人倍率": "new_openings_ratio",
    "有効求人倍率": "active_openings_ratio",
}
SHEET_RE = re.compile(r"(?P<measure>新規求人数|新規求職申込件数|有効求人数|有効求職者数|新規求人倍率|有効求人倍率)\((?P<kind>実数|季節調整値)\)$")
NATIONWIDE = "全国"
YEAR_RE = re.compile(r"^(\d{4})年(度)?$")
MONTH_RE = re.compile(r"^(\d{1,2})月$")
# 毎月末に前月分が出る。最新の月が今月から3か月より前なら、差し替えが止まっている
MAX_LAG_MONTHS = 3

_KEY = [
    ("period_type", pa.string()),
    ("year", pa.int16()),
    ("month", pa.int8()),
    ("basis", pa.string()),
    ("seasonally_adjusted", pa.bool_()),
    ("area", pa.string()),
    ("area_name", pa.string()),
]
SCHEMA = pa.schema(_KEY + [(c, pa.float64()) for c in MEASURES.values()])


def _norm(s: str) -> str:
    return re.sub(r"\s+", "", unicodedata.normalize("NFKC", s))


def file_urls(app_id: str) -> dict[str, str]:
    """表ごとに、いちばん新しい調査年月の Excel の URL を返す。旧様式のファイルも同じ名前で残っている。"""
    found: dict[str, list[tuple[str, str]]] = {key: [] for key in TABLES}
    seen: set[str] = set()
    start_position = 1
    while True:
        params = {
            "appId": app_id,
            "statsCode": STATS_CODE,
            "searchWord": SEARCH_WORD,
            "limit": PAGE_LIMIT,
            "startPosition": start_position,
        }
        root = json.loads(_fetch(f"{CATALOG_URL}?{urllib.parse.urlencode(params)}"))["GET_DATA_CATALOG"]
        if root["RESULT"]["STATUS"] not in (EstatStatus.OK, EstatStatus.PARTIAL):
            raise RuntimeError(f"getDataCatalog: API error: {root['RESULT'].get('ERROR_MSG', '')}")
        listing = root["DATA_CATALOG_LIST_INF"]
        items = listing.get("DATA_CATALOG_INF", [])
        for item in [items] if isinstance(items, dict) else items:
            survey_date = str(item["DATASET"]["TITLE"]["SURVEY_DATE"])
            resources = item["RESOURCES"]["RESOURCE"]
            for r in [resources] if isinstance(resources, dict) else resources:
                title = r["TITLE"]
                names = {_norm(str(title.get(k) or "")) for k in ("NAME", "TABLE_NAME")}
                if any("都道府県" in n and SEARCH_WORD in n for n in names):
                    seen.add(f"{title.get('NAME')} [{r['FORMAT']}]")
                for key, (table_title, _) in TABLES.items():
                    if _norm(table_title) in names and r["FORMAT"] in EXCEL_FORMATS:
                        found[key].append((survey_date, r["URL"]))
        next_key = listing.get("RESULT_INF", {}).get("NEXT_KEY")
        if not next_key:
            break
        if int(next_key) <= start_position:
            raise RuntimeError(f"getDataCatalog: NEXT_KEY {next_key} が startPosition {start_position} から進まない")
        start_position = int(next_key)
    missing = [TABLES[key][0] for key, urls in found.items() if not urls]
    if missing:
        raise RuntimeError(f"一般職業紹介状況の Excel が見つからない: {missing} (都道府県別の候補: {sorted(seen)})")
    return {key: max(urls)[1] for key, urls in found.items()}


def _number(cell) -> float | None:
    if cell is None:
        return None
    if isinstance(cell, (int, float)):
        return float(cell)
    raise RuntimeError(f"数値でないセル: {cell!r}")


def _area(name: str) -> tuple[str, str]:
    if name == NATIONWIDE:
        return "00000", name
    return f"{PREFECTURES.index(name) + 1:02d}000", name


def _parse_sheet(rows: list[tuple], sheet: str) -> dict[tuple, float | None]:
    """シートを (period_type, year, month, area) → 値 にする。"""
    header = rows[1]
    if _norm(str(header[0])) != "西暦" or header[2] is not None:
        raise RuntimeError(f"{sheet}: 見出しの行が想定と違う: {header[:4]}")
    columns = [(i, _norm(h)) for i, h in enumerate(header) if i >= 3 and h is not None]
    unknown = [h for _, h in columns if h != NATIONWIDE and h not in PREFECTURES]
    if unknown or len([h for _, h in columns if h in PREFECTURES]) != 47:
        raise RuntimeError(f"{sheet}: 都道府県の列が想定と違う: {unknown}")
    values = {}
    for row in rows[3:]:
        label = _norm(str(row[0])) if row[0] is not None else ""
        m = YEAR_RE.match(label)
        if not m:
            continue  # 空行と末尾の注
        year = int(m.group(1))
        if row[2] is None:
            period_type, month = ("年度" if m.group(2) else "年"), None
        else:
            mm = MONTH_RE.match(_norm(str(row[2])))
            if not mm or m.group(2):
                raise RuntimeError(f"{sheet}: 月の行が読めない: {row[:3]}")
            period_type, month = "月", int(mm.group(1))
        for i, name in columns:
            values[(period_type, year, month, name)] = _number(row[i])
    return values


def parse(body: bytes, basis: str) -> pa.Table:
    """1 ファイルを、期間・地域・実数か季節調整値かごとに 1 行の表にする。"""
    book = openpyxl.load_workbook(io.BytesIO(body), read_only=True, data_only=True)
    sheets: dict[tuple[str, str], dict] = {}
    for sheet in book.sheetnames:
        m = SHEET_RE.search(_norm(sheet))
        if not m:
            raise RuntimeError(f"知らないシート: {sheet}")
        sheets[(MEASURES[m.group("measure")], m.group("kind"))] = _parse_sheet(
            list(book[sheet].iter_rows(values_only=True)), sheet
        )
    records = {}
    for (measure, kind), values in sheets.items():
        for (period_type, year, month, name), value in values.items():
            area, area_name = _area(name)
            key = (period_type, year, month, kind == "季節調整値", area)
            rec = records.setdefault(
                key,
                {
                    "period_type": period_type,
                    "year": year,
                    "month": month,
                    "basis": BASIS_NAMES[basis],
                    "seasonally_adjusted": kind == "季節調整値",
                    "area": area,
                    "area_name": area_name,
                },
            )
            rec[measure] = value
    return pa.Table.from_pylist(list(records.values()), schema=SCHEMA)


def _check(table: pa.Table, basis: str) -> None:
    cols = ("period_type", "seasonally_adjusted", "year", "month")
    months = sorted({(y, m) for t, sa, y, m in zip(*(table.column(c).to_pylist() for c in cols)) if t == "月" and not sa})
    first = TABLES[basis][1]
    if months[0] != first:
        raise RuntimeError(f"{BASIS_NAMES[basis]}別の実数が {first} から始まっていない: {months[0]}")
    today = date.today()
    lag = (today.year * 12 + today.month) - (months[-1][0] * 12 + months[-1][1])
    if lag > MAX_LAG_MONTHS:
        raise RuntimeError(f"{BASIS_NAMES[basis]}別の最新の月が {months[-1]} で {lag} か月遅れている")


def build_job_placement(dest_dir: str, app_id: str) -> None:
    """受理地別と就業地別の Excel を取り、縦持ちの Parquet に書く。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)
    for basis, url in file_urls(app_id).items():
        table = parse(_fetch(url), basis)
        _check(table, basis)
        pq.write_table(table, dest / f"prefecture_{basis}.parquet")
        logger.info(f"  job_placement prefecture_{basis}: {table.num_rows} 行")
