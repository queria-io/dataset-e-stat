"""学校保健統計調査の取得 (getDataCatalog + 統計表 Excel)。

幼稚園・小学校・中学校・高等学校の在学者から標本を抜き、4〜6 月の健康診断の結果を
集計する調査。ここで取るのは都道府県表の「都道府県別 身長・体重の平均値及び
標準偏差」で、5〜17 歳の年齢ごと・男女ごとに、身長・体重 (2015 年度までは座高も) の
平均値と標準偏差が全国と 47 都道府県で並ぶ。

■ getStatsData を使わない理由

この表は e-Stat のデータベースにもある (2015 年度以降は 0003146482) が、time 軸が
2019 年度で止まっている。それ以降の年度は統計表ファイルだけで出ているので、全年度を
ファイルから読む。データベースの値は 1996〜2019 年度の検算に使える。

■ 取り込む調査年度

1996 年度 (平成8年度) から。getDataCatalog に Excel で載るのはこの年度からで、
それより前は PDF しか無い。確定値は翌年の 2〜3 月に出る (2021〜2023 年度は
同じ年の 11 月)。

座高は 2015 年度を最後に健康診断の必須項目から外れ、2016 年度から表に無い。

■ 表の形

1 年齢 1 シートで 13 シート。年度によって 2 通りに揺れる。

- 男と女のブロックが横に並び、それぞれに「区分」の列がある (1996〜2001 年度ごろ)。
  年齢の見出しは「5歳-男」のように男女を含む
- 「区分」の列は 1 つで、その右に男・女の見出しが横に並ぶ (それ以降)

どちらでも、値の列ごとに上の見出しを集めて (年齢・男女・項目・平均値か標準偏差か)
を決める。見出しの空欄は右へ送る。行は全国と都道府県名で拾う。都道府県名は
「青森」「青森県」と年度で揺れる。

データソース: 文部科学省 学校保健統計調査
https://www.e-stat.go.jp/stat-search/files?toukei=00400002
"""

import io
import json
import logging
import re
import unicodedata
import urllib.parse
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path

import pandas as pd

from pipelines import EstatStatus, check_latest_year
from pipelines.school import NATIONWIDE_CODE, PAGE_LIMIT, PREFECTURES, _fetch

logger = logging.getLogger("pipelines")

CATALOG_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getDataCatalog"
STATS_CODE = "00400002"

FIRST_SURVEY_YEAR = 1996
# 調査年度 N の確定値は N+1 年 3 月までに出る (check_latest_year)。
LATEST_LAG_YEARS = 1
# 座高が表にある最後の年度。
LAST_SITTING_HEIGHT_YEAR = 2015

TABLE_NAME_RE = re.compile(r"^都道府県別身長・体重(・座高)?の平均値及び標準偏差$")
FILE_FORMATS = {"XLS", "XLS_REP"}
AGES = range(5, 18)

SEX_CODES = {"男": "1", "女": "2"}
MEASURES = {"身長": "height", "体重": "weight", "座高": "sitting_height"}
STATS = {"平均値": "mean", "標準偏差": "sd"}
# 公表の桁。1999・2000・2011 年度のファイルは表示より細かい値を持つセルがあり、
# 丸めるとデータベースの値と全セルで一致する。
DIGITS = {"mean": Decimal("0.1"), "sd": Decimal("0.01")}
AGE_RE = re.compile(r"^(\d+)歳(?:[-―‐](男|女))?$")
# 調査しなかった県のセル。2011 年度の岩手・宮城・福島 (東日本大震災) がこれで埋まる。
MISSING_VALUES = {"...", "…"}
NUMBER_RE = re.compile(r"^\d+(\.\d+)?$")


def _norm(cell) -> str:
    """全角数字・全角空白を畳み、空白と改行を除く。"""
    if cell is None or (isinstance(cell, float) and pd.isna(cell)):
        return ""
    s = unicodedata.normalize("NFKC", str(cell))
    return re.sub(r"\s", "", s)


def _measure(label: str) -> str | None:
    """「身長(cm)」「身長」のような見出しから項目を返す。"""
    for name, key in MEASURES.items():
        if label.startswith(name):
            return key
    return None


def catalog(app_id: str) -> list[tuple[int, str]]:
    """都道府県別の身長・体重の表の所在を (調査年度, URL) で集める。"""
    found: dict[int, str] = {}
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
            # SURVEY_DATE は「202504-202603」(年度) の形。1996 年度だけ「1996」。
            survey_year = int(str(title["SURVEY_DATE"])[:4] or 0)
            if survey_year < FIRST_SURVEY_YEAR:
                continue
            resources = item["RESOURCES"]["RESOURCE"]
            if isinstance(resources, dict):
                resources = [resources]
            for res in resources:
                if not TABLE_NAME_RE.match(_norm(res["TITLE"].get("TABLE_NAME"))):
                    continue
                if res["FORMAT"] not in FILE_FORMATS:
                    continue
                if survey_year in found:
                    raise RuntimeError(f"{survey_year}年度 都道府県別の身長・体重の表が 2 つある")
                found[survey_year] = res["URL"]

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
        raise RuntimeError(f"getDataCatalog に {STATS_CODE} の都道府県別の身長・体重の表が無い")

    # 表題が変わって 1 年度だけ落ちても、ほかの年度の行は残るので行数でも値でも
    # 気づけない。年度の連続をここで押さえる。
    years = sorted(found)
    check_latest_year(years[-1], LATEST_LAG_YEARS)
    if missing := [y for y in range(FIRST_SURVEY_YEAR, years[-1] + 1) if y not in found]:
        raise RuntimeError(f"都道府県別の身長・体重の表が欠けている: {missing}")
    return sorted(found.items())


def _area(label: str) -> tuple[str, str | None, str] | None:
    """行見出しから (地域コード, 都道府県コード, 名前) を返す。"""
    if label == "全国":
        return NATIONWIDE_CODE, None, "全国"
    for index, name in enumerate(PREFECTURES, start=1):
        if label in (name, name + "県", name + "府", name + "都"):
            return f"{index:02d}000", f"{index:02d}", name
    return None


def _spread(values: list[str]) -> list[str]:
    """見出しの空欄を右へ送る。「区分」で送りを切る。"""
    filled, carried = [], ""
    for value in values:
        if value == "区分":
            carried = ""
        elif value:
            carried = value
        filled.append(carried)
    return filled


def parse_sheet(sheet: pd.DataFrame, survey_year: int, where: str) -> list[dict]:
    """1 年齢分のシートを 地域 × 男女 の行にする。"""
    rows = [[_norm(c) for c in sheet.iloc[i].tolist()] for i in range(len(sheet))]
    stat_row = next(
        (i for i, r in enumerate(rows) if "平均値" in r and "標準偏差" in r), None
    )
    if stat_row is None:
        raise RuntimeError(f"{where}: 平均値・標準偏差の見出しが無い")
    header = [_spread(r) for r in rows[:stat_row]]

    # 値の列ごとに (年齢, 男女, 項目, 統計量) を決める。
    columns: list[tuple[int, int, str, str, str]] = []
    for c, stat in enumerate(rows[stat_row]):
        if stat not in STATS:
            continue
        age = sex = measure = None
        for r in header:
            label = r[c]
            if m := AGE_RE.match(label):
                age = int(m.group(1))
                sex = m.group(2) or sex
            elif label in SEX_CODES:
                sex = label
            elif key := _measure(label):
                measure = key
        if age is None or sex is None or measure is None:
            raise RuntimeError(f"{where} 列{c}: 見出しが読めない: {age} {sex} {measure}")
        columns.append((c, age, SEX_CODES[sex], measure, STATS[stat]))

    ages = {age for _, age, _, _, _ in columns}
    if len(ages) != 1:
        raise RuntimeError(f"{where}: 1 シートに年齢が {sorted(ages)}")
    age = ages.pop()
    measures = (
        set(MEASURES.values())
        if survey_year <= LAST_SITTING_HEIGHT_YEAR
        else {"height", "weight"}
    )
    expected = {(s, m, st) for s in SEX_CODES.values() for m in measures for st in STATS.values()}
    got = [(s, m, st) for _, _, s, m, st in columns]
    if sorted(got) != sorted(expected):
        raise RuntimeError(f"{where}: 列がそろわない: {sorted(got)}")

    # 行見出しは値の列より左で、最も近い値でないセル。
    values: dict[tuple[str, str], dict] = {}
    for i in range(stat_row + 1, len(rows)):
        row = rows[i]
        for c, _, sex_code, measure, stat in columns:
            label = next(
                (
                    v
                    for v in reversed(row[:c])
                    if v and v not in MISSING_VALUES and not NUMBER_RE.match(v)
                ),
                "",
            )
            area = _area(label)
            if area is None:
                continue
            cell = row[c]
            if cell not in MISSING_VALUES and not NUMBER_RE.match(cell):
                raise RuntimeError(f"{where} {label}: 数値として読めないセル {cell!r}")
            record = values.setdefault(
                (area[0], sex_code),
                {
                    "survey_year": survey_year,
                    "age": age,
                    "sex_code": sex_code,
                    "area": area[0],
                    "prefecture_code": area[1],
                    "area_label": label,
                },
            )
            key = f"{measure}_{stat}"
            if key in record:
                raise RuntimeError(f"{where} {label}: {key} が 2 回ある")
            record[key] = (
                None
                if cell in MISSING_VALUES
                else float(Decimal(cell).quantize(DIGITS[stat], ROUND_HALF_UP))
            )

    if len(values) != 48 * len(SEX_CODES):
        raise RuntimeError(f"{where}: 地域 × 男女 が {len(values)} 組 (96 組のはず)")
    return list(values.values())


def parse(body: bytes, survey_year: int) -> list[dict]:
    """1 年度分のファイルを 年齢 × 地域 × 男女 の行にする。"""
    sheets = pd.read_excel(io.BytesIO(body), sheet_name=None, header=None, dtype=object)
    records = []
    for sheet_name, sheet in sheets.items():
        records += parse_sheet(sheet, survey_year, f"{survey_year}年度 {sheet_name}")
    ages = sorted({r["age"] for r in records})
    if ages != list(AGES) or len(records) != len(AGES) * 48 * len(SEX_CODES):
        raise RuntimeError(f"{survey_year}年度: 年齢がそろわない: {ages} ({len(records)} 行)")
    return records


def build_school_health(dest_dir: str, app_id: str) -> None:
    """都道府県別の身長・体重の表を取得し、NDJSON に整形する。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)

    records: list[dict] = []
    for survey_year, url in catalog(app_id):
        parsed = parse(_fetch(url), survey_year)
        logger.info(f"  {survey_year}: {len(parsed)} rows")
        records += parsed

    with (dest / "growth_by_prefecture.ndjson").open("w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
    years = sorted({r["survey_year"] for r in records})
    logger.info(f"  growth_by_prefecture={len(records)} rows, {years[0]}-{years[-1]}年度")
