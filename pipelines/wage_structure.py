"""賃金構造基本統計調査の取得 (getDataCatalog + 統計表 Excel)。

一般労働者 (短時間労働者以外の常用労働者) の賃金を、都道府県別に取る。ここで取るのは
「一般労働者_都道府県別」の参考表 2 つで、どちらも 1 年 1 ファイル。

- 参考表1 (sanko1): 性、都道府県別の年齢・勤続年数・実労働時間数・きまって支給する
  現金給与額・所定内給与額・年間賞与その他特別給与額・労働者数
- 参考表2 (sanko2): 性、都道府県、産業 (大分類) 別の所定内給与額・年間賞与その他特別給与額

■ getStatsData を使わない理由

この統計は e-Stat のデータベースにも表がある (参考表1 は 0004007160) が、収録が
2023 年で止まっている (2024-11-27 更新が最後)。2024 年・2025 年の表は統計表ファイル
だけで出ているので、全年をファイルから読む。

■ 取り込む調査年

2020 年 (令和2年) から。2020 年調査で一部の調査事項と推計方法が変わり、厚生労働省は
それまでの公表値との比較には注意が必要としている。表の形は 2020 年から同じ。
2020 年のファイルは xls、2021 年からは xlsx。

■ 表の形

参考表1 は「男女計」「男女別」の 2 シート。男女別のシートは男と女のブロックが横に
並ぶ。行見出しは都道府県名だけでコードが無い (「青　森」のように全角空白が入る)
ので、全国の次から JIS の都道府県コード順に 01〜47 を振る。並びは stg で都道府県名と
突き合わせて確かめる。

参考表2 は「男女計」「男」「女」の 3 シート。行見出しに 1〜47 の番号と都道府県名が
入る。産業は列見出しに「Ｃ　鉱業，採石業，砂利採取業」の形で並び、産業計の列は無い
(産業計は参考表1 にある)。

データソース: 厚生労働省 賃金構造基本統計調査
https://www.e-stat.go.jp/stat-search/files?toukei=00450091
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

from pipelines import EstatStatus, check_latest_year

logger = logging.getLogger("pipelines")

CATALOG_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getDataCatalog"
STATS_CODE = "00450091"
_UA = "dataset-e-stat"
_TIMEOUT = 300
# welfare_facility と同じ理由。統計表ファイルの配信は、存在する URL に対しても
# 404 を返す窓を持つので、404 も一時障害として待つ。
_TRANSIENT_HTTP_CODES = {404, 500, 502, 503, 504}
_MAX_RETRIES = 8
_MAX_WAIT = 30
_MAX_NETWORK_RETRIES = 4
# getDataCatalog の 1 リクエストあたり上限。超えると status 102 で弾かれる。
PAGE_LIMIT = 100

FIRST_SURVEY_YEAR = 2020
# 調査年 N の表は N+1 年 3 月に出る (check_latest_year)。
LATEST_LAG_YEARS = 1

DATASET_MARKER = "一般労働者_都道府県別"
TABLES = ("sanko1", "sanko2")
FILE_FORMATS = {"XLS", "XLS_REP"}

PREFECTURE_COUNT = 47
# 参考表2 の産業。日本標準産業分類の大分類 C〜R。
INDUSTRY_COUNT = 16
NATIONWIDE_CODE = "00000"

SEX_CODES = {"男女計": "0", "男": "1", "女": "2"}

# 参考表1 の指標。単位の行がこの並びでそろうことを確かめてから読む。
SANKO1_MEASURES = [
    ("age", "歳"),
    ("tenure_years", "年"),
    ("scheduled_hours", "時間"),
    ("overtime_hours", "時間"),
    ("contractual_earnings", "千円"),
    ("scheduled_earnings", "千円"),
    ("annual_special_earnings", "千円"),
    ("workers", "十人"),
]
# 参考表2 の指標。見出しは「所定内」「給与額」、「年　間」「賞与額」の 2 行に割れる。
SANKO2_MEASURES = {
    "所定内給与額": "scheduled_earnings",
    "年間賞与額": "annual_special_earnings",
}
INDUSTRY_RE = re.compile(r"^([Ａ-ＺA-Z])\s*(.+)$")
BLANK_VALUES = {"", "-", "－", "…", "‥", "*", "x", "X", "・", "nan"}


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
    if cell is None or (isinstance(cell, float) and pd.isna(cell)):
        return ""
    return str(cell).replace("　", "").replace(" ", "").replace("\n", "").strip()


def catalog(app_id: str) -> list[tuple[int, str, str]]:
    """参考表の所在を (調査年, 表番号, URL) で集める。"""
    found: dict[tuple[int, str], str] = {}
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
            title = item["DATASET"]["TITLE"]
            if DATASET_MARKER not in title["NAME"]:
                continue
            survey_year = int(title["SURVEY_DATE"])
            if survey_year < FIRST_SURVEY_YEAR:
                continue
            resources = item["RESOURCES"]["RESOURCE"]
            if isinstance(resources, dict):
                resources = [resources]
            for res in resources:
                table_no = str(res["TITLE"]["TABLE_NO"])
                if table_no not in TABLES or res["FORMAT"] not in FILE_FORMATS:
                    continue
                key = (survey_year, table_no)
                if key in found:
                    raise RuntimeError(f"{survey_year}年調査の {table_no} が 2 つある")
                found[key] = res["URL"]

        next_key = listing.get("RESULT_INF", {}).get("NEXT_KEY")
        if not next_key:
            break
        if int(next_key) <= start_position:
            raise RuntimeError(
                f"getDataCatalog: NEXT_KEY {next_key} が "
                f"startPosition {start_position} から進まない"
            )
        start_position = int(next_key)

    if not found:
        raise RuntimeError(f"getDataCatalog に {STATS_CODE} の参考表が無い")

    # 表題が変わって 1 年分だけ落ちても、ほかの年の行はそのまま残るので行数でも
    # 値でも気づけない。年の連続と、2 つの表がそろうことをここで押さえる。
    years = sorted({year for year, _ in found})
    check_latest_year(years[-1], LATEST_LAG_YEARS)
    if missing := [
        (year, table)
        for year in range(FIRST_SURVEY_YEAR, years[-1] + 1)
        for table in TABLES
        if (year, table) not in found
    ]:
        raise RuntimeError(f"参考表が欠けている: {missing}")

    return sorted((year, table, url) for (year, table), url in found.items())


def _value(cell) -> float | None:
    s = _norm(cell).replace(",", "")
    if s in BLANK_VALUES:
        return None
    try:
        return float(s)
    except ValueError:
        raise RuntimeError(f"数値として読めないセル: {cell!r}") from None


def _spread(values: list[str]) -> list[str]:
    """見出しの空欄を右へ送る。"""
    filled: list[str] = []
    carried = ""
    for value in values:
        if value:
            carried = value
        filled.append(carried)
    return filled


def _find_row(sheet: pd.DataFrame, predicate) -> int:
    for i in range(len(sheet)):
        if predicate([_norm(c) for c in sheet.iloc[i].tolist()]):
            return i
    raise RuntimeError("見出しの行が見つからない")


def _area(index: int) -> tuple[str, str | None]:
    """全国を 0、都道府県を 1〜47 とした通し番号から地域コードを返す。"""
    if index == 0:
        return NATIONWIDE_CODE, None
    return f"{index:02d}000", f"{index:02d}"


def parse_sanko1(body: bytes, survey_year: int) -> list[dict]:
    """参考表1 を 年 × 都道府県 × 性 の 1 行にする。"""
    sheets = pd.read_excel(io.BytesIO(body), sheet_name=None, header=None, dtype=object)
    records = []
    for sheet in sheets.values():
        unit_row = _find_row(sheet, lambda r: "歳" in r and "十人" in r)
        units = [_norm(c) for c in sheet.iloc[unit_row].tolist()]
        sex_row = _find_row(sheet, lambda r: any(c in SEX_CODES for c in r))
        sexes = _spread([_norm(c) for c in sheet.iloc[sex_row].tolist()])

        # 単位の行から指標のブロックを切り出す。1 ブロック = 1 つの性。
        starts = [c for c, u in enumerate(units) if u == "歳"]
        expected = [u for _, u in SANKO1_MEASURES]
        blocks = []
        for start in starts:
            got = units[start : start + len(expected)]
            if got != expected:
                raise RuntimeError(f"{survey_year}年 参考表1 の単位の並びが違う: {got}")
            sex = sexes[start]
            if sex not in SEX_CODES:
                raise RuntimeError(f"{survey_year}年 参考表1 の性が読めない: {sex!r}")
            blocks.append((sex, start))

        # 行見出しは単位の行より左の列のどこかにある。
        label_col = min(starts) - 1
        while label_col >= 0 and not any(
            _norm(v) for v in sheet.iloc[unit_row + 1 :, label_col]
        ):
            label_col -= 1
        labels = [
            (i, _norm(sheet.iat[i, label_col]))
            for i in range(unit_row + 1, len(sheet))
            if _norm(sheet.iat[i, label_col])
        ]
        if len(labels) != PREFECTURE_COUNT + 1 or labels[0][1] != "全国":
            raise RuntimeError(
                f"{survey_year}年 参考表1 の行が全国+47都道府県になっていない: {len(labels)} 行"
            )

        for index, (row, name) in enumerate(labels):
            area, prefecture_code = _area(index)
            for sex, start in blocks:
                record = {
                    "survey_year": survey_year,
                    "area": area,
                    "area_name": name,
                    "prefecture_code": prefecture_code,
                    "sex_code": SEX_CODES[sex],
                    "sex": sex,
                }
                for offset, (measure, _) in enumerate(SANKO1_MEASURES):
                    record[measure] = _value(sheet.iat[row, start + offset])
                records.append(record)

    sexes_found = {r["sex_code"] for r in records}
    if sexes_found != set(SEX_CODES.values()):
        raise RuntimeError(f"{survey_year}年 参考表1 の性がそろわない: {sexes_found}")
    return records


def parse_sanko2(body: bytes, survey_year: int) -> list[dict]:
    """参考表2 を 年 × 都道府県 × 産業 × 性 の 1 行にする。"""
    sheets = pd.read_excel(io.BytesIO(body), sheet_name=None, header=None, dtype=object)
    if set(sheets) != set(SEX_CODES):
        raise RuntimeError(f"{survey_year}年 参考表2 のシートが違う: {list(sheets)}")
    records = []
    for sex, sheet in sheets.items():
        industry_row = _find_row(sheet, lambda r: any(INDUSTRY_RE.match(c) for c in r))
        industries = _spread([_norm(c) for c in sheet.iloc[industry_row].tolist()])
        measures = [
            _norm(a) + _norm(b)
            for a, b in zip(
                sheet.iloc[industry_row + 1].tolist(),
                sheet.iloc[industry_row + 2].tolist(),
                strict=True,
            )
        ]
        columns = []
        for c, (industry, measure) in enumerate(zip(industries, measures, strict=True)):
            if not measure:
                continue
            if measure not in SANKO2_MEASURES:
                raise RuntimeError(
                    f"{survey_year}年 参考表2 の指標が読めない: {measure!r}"
                )
            m = INDUSTRY_RE.match(industry)
            if not m:
                raise RuntimeError(
                    f"{survey_year}年 参考表2 の産業が読めない: {industry!r}"
                )
            code = unicodedata.normalize("NFKC", m.group(1))
            columns.append((c, code, m.group(2), SANKO2_MEASURES[measure]))

        # 見出しがずれて産業と指標の組が欠けたり重なったりすると、値が NULL に
        # なるか後の列で上書きされたまま通る。16 産業 × 2 指標がちょうどそろうことを見る。
        pairs = [(code, measure) for _, code, _, measure in columns]
        industries_found = {code for code, _ in pairs}
        if len(industries_found) != INDUSTRY_COUNT or sorted(pairs) != sorted(
            (code, measure)
            for code in industries_found
            for measure in SANKO2_MEASURES.values()
        ):
            raise RuntimeError(
                f"{survey_year}年 参考表2 {sex} の産業と指標の列がそろわない: {pairs}"
            )

        cells: dict[tuple[str, str], dict] = {}
        prefectures = 0
        for i in range(industry_row + 3, len(sheet)):
            head = _norm(sheet.iat[i, 0])
            if not head:
                continue
            # 番号は xls だと 1.0 のような浮動小数で読める。
            number = re.fullmatch(r"(\d+)(\.0)?", head)
            if head == "全国計":
                area, prefecture_code, name = _area(0) + ("全国",)
            elif number:
                area, prefecture_code = _area(int(number.group(1)))
                name = _norm(sheet.iat[i, 1])
                prefectures += 1
            else:
                raise RuntimeError(
                    f"{survey_year}年 参考表2 の行見出しが読めない: {head!r}"
                )
            for c, code, industry, measure in columns:
                record = cells.setdefault(
                    (area, code),
                    {
                        "survey_year": survey_year,
                        "area": area,
                        "area_name": name,
                        "prefecture_code": prefecture_code,
                        "industry_code": code,
                        "industry": industry,
                        "sex_code": SEX_CODES[sex],
                        "sex": sex,
                        "scheduled_earnings": None,
                        "annual_special_earnings": None,
                    },
                )
                record[measure] = _value(sheet.iat[i, c])
        if prefectures != PREFECTURE_COUNT:
            raise RuntimeError(
                f"{survey_year}年 参考表2 {sex} の都道府県が {prefectures} 行 (47 行のはず)"
            )
        records += cells.values()
    return records


def build_wage_structure(dest_dir: str, app_id: str) -> None:
    """参考表を取得し、都道府県別・産業別の賃金を NDJSON に整形する。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)

    parsers = {"sanko1": parse_sanko1, "sanko2": parse_sanko2}
    outputs = {"sanko1": "prefecture.ndjson", "sanko2": "prefecture_industry.ndjson"}
    records: dict[str, list[dict]] = {table: [] for table in TABLES}
    for survey_year, table, url in catalog(app_id):
        parsed = parsers[table](_fetch(url), survey_year)
        logger.info(f"  {survey_year} {table}: {len(parsed)} rows")
        records[table] += parsed

    for table, rows in records.items():
        if not rows:
            raise RuntimeError(f"{table} の行が 1 件も無い")
        with (dest / outputs[table]).open("w", encoding="utf-8") as f:
            for record in rows:
                f.write(json.dumps(record, ensure_ascii=False) + "\n")
        years = sorted({r["survey_year"] for r in rows})
        logger.info(f"  {table}={len(rows)} rows, {years[0]}-{years[-1]}年調査")
