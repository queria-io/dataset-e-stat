"""学校基本調査の取得 (getDataCatalog + 統計表 Excel)。

小学校の「学年別児童数」と中学校の「学年別生徒数」を、都道府県別・設置者別・男女別に取る。
どちらも 1 年 1 ファイルで、設置者 (計・国立・公立・私立) ごとにブロックが分かれる。

■ getStatsData を使わない理由

この統計は e-Stat のデータベースにも表がある (小学校の学年別児童数は 0003065485) が、
time 軸が 2011〜2013 年で止まっている。それ以降の年は統計表ファイルだけで出ているので、
全年をファイルから読む。

■ 取り込む調査年

2000 年 (平成12年度) から。getDataCatalog に載る学年別の表はこの年からで、
それより前は年次統計の別の表しか無い。調査は毎年 5 月 1 日現在で、確定値は同じ年の
12 月に出る。8 月の速報は表の形が違うので読まない。

■ 表の形

年によって 3 通りに揺れる。

- 設置者ごとに 1 シート (小学校の全年、中学校の 2003・2009・2010・2021 年以降)
- 国立と公立が 1 シートに横並び (中学校のそれ以外の年)
- 見出しの位置・全角数字・都道府県名の「県」の有無

どの形でも、学年の見出し行にある「区分」から次の「区分」までを 1 ブロックとし、
ブロックの上にある「1.計」「2.国立」のような見出しで設置者を決める。行は都道府県名で
拾い、全国は北海道の直前にある数値の行 (当年の計) を使う。その上には前年の計の行が
あるので、北海道より前で最後の行だけを取る。

データソース: 文部科学省 学校基本調査
https://www.e-stat.go.jp/stat-search/files?toukei=00400001
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
STATS_CODE = "00400001"
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

FIRST_SURVEY_YEAR = 2000
# 調査年 N の確定値は N 年 12 月に出る (check_latest_year)。
LATEST_LAG_YEARS = 1

# (school_type, 学校種の名前, 表の名前, 学年数)
SCHOOL_TYPES = {
    "elementary": ("小学校", "学年別児童数", 6),
    "junior_high": ("中学校", "学年別生徒数", 3),
}
FILE_FORMATS = {"XLS", "XLS_REP"}

PREFECTURES = (
    "北海道",
    "青森",
    "岩手",
    "宮城",
    "秋田",
    "山形",
    "福島",
    "茨城",
    "栃木",
    "群馬",
    "埼玉",
    "千葉",
    "東京",
    "神奈川",
    "新潟",
    "富山",
    "石川",
    "福井",
    "山梨",
    "長野",
    "岐阜",
    "静岡",
    "愛知",
    "三重",
    "滋賀",
    "京都",
    "大阪",
    "兵庫",
    "奈良",
    "和歌山",
    "鳥取",
    "島根",
    "岡山",
    "広島",
    "山口",
    "徳島",
    "香川",
    "愛媛",
    "高知",
    "福岡",
    "佐賀",
    "長崎",
    "熊本",
    "大分",
    "宮崎",
    "鹿児島",
    "沖縄",
)
NATIONWIDE_CODE = "00000"

FOUNDERS = {"計": "0", "国立": "1", "公立": "2", "私立": "3"}
FOUNDER_RE = re.compile(r"^\d\.(計|国立|公立|私立)$")
SEX_CODES = {"計": "0", "男": "1", "女": "2"}
GRADE_RE = re.compile(r"^(\d)学年$")
NUMBER_RE = re.compile(r"^\d+(\.0)?$")
# 原典で該当が無いセル。学校基本調査ではどれも 0 の意味で使われる。
ZERO_VALUES = {"-", "―", "‐", "－", "−"}


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
    """全角数字・全角空白を畳み、空白と改行を除く。"""
    if cell is None or (isinstance(cell, float) and pd.isna(cell)):
        return ""
    s = unicodedata.normalize("NFKC", str(cell))
    return s.replace(" ", "").replace("\n", "").strip()


def _school_type(title: dict) -> str | None:
    """データセットの表題から学校種を決める。学校調査の小学校・中学校の確定値だけを拾う。"""
    name = title["NAME"]
    if "学校調査" not in name or "速報" in name:
        return None
    survey_year = title["SURVEY_DATE"]
    for school_type, (label, _, _) in SCHOOL_TYPES.items():
        # 2022 年までは表題の末尾が「_小学校_2022年」、2023 年からは
        # 「_学校調査票（小学校）_2023年」。
        if (
            name.endswith(f"_{label}_{survey_year}年")
            or f"学校調査票（{label}）" in name
        ):
            return school_type
    return None


def catalog(app_id: str) -> list[tuple[int, str, str]]:
    """学年別の表の所在を (調査年, 学校種, URL) で集める。"""
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
            survey_year = title["SURVEY_DATE"]
            if not isinstance(survey_year, int) or survey_year < FIRST_SURVEY_YEAR:
                continue
            school_type = _school_type(title)
            if school_type is None:
                continue
            table_name = SCHOOL_TYPES[school_type][1]
            resources = item["RESOURCES"]["RESOURCE"]
            if isinstance(resources, dict):
                resources = [resources]
            for res in resources:
                if res["TITLE"]["TABLE_NAME"] != table_name:
                    continue
                if res["FORMAT"] not in FILE_FORMATS:
                    continue
                key = (survey_year, school_type)
                if key in found:
                    raise RuntimeError(f"{survey_year}年 {table_name} が 2 つある")
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
        raise RuntimeError(f"getDataCatalog に {STATS_CODE} の学年別の表が無い")

    # 表題が変わって 1 年分だけ落ちても、ほかの年の行はそのまま残るので行数でも
    # 値でも気づけない。年の連続と、2 つの学校種がそろうことをここで押さえる。
    years = sorted({year for year, _ in found})
    check_latest_year(years[-1], LATEST_LAG_YEARS)
    if missing := [
        (year, school_type)
        for year in range(FIRST_SURVEY_YEAR, years[-1] + 1)
        for school_type in SCHOOL_TYPES
        if (year, school_type) not in found
    ]:
        raise RuntimeError(f"学年別の表が欠けている: {missing}")

    return sorted(
        (year, school_type, url) for (year, school_type), url in found.items()
    )


def _prefecture_index(label: str) -> int | None:
    """行見出しから都道府県の番号 (1〜47) を返す。「青森」「青森県」のどちらでも当てる。"""
    for index, name in enumerate(PREFECTURES, start=1):
        if label in (name, name + "県", name + "府", name + "都"):
            return index
    return None


def _value(cell, where: str) -> int:
    s = _norm(cell).replace(",", "")
    if s in ZERO_VALUES:
        return 0
    if not NUMBER_RE.match(s):
        raise RuntimeError(f"{where}: 数値として読めないセル {cell!r}")
    return int(float(s))


def _spread(values: list[str]) -> list[str]:
    """見出しの空欄を右へ送る。「区分」で送りを切る。"""
    filled: list[str] = []
    carried = ""
    for value in values:
        if value == "区分":
            carried = ""
        elif value:
            carried = value
        filled.append(carried)
    return filled


def parse(body: bytes, survey_year: int, school_type: str) -> list[dict]:
    """学年別の表を 年 × 学校種 × 設置者 × 地域 × 学年 × 性 の 1 行にする。"""
    _, table_name, grades = SCHOOL_TYPES[school_type]
    expected_columns = [("0", "0"), ("0", "1"), ("0", "2")] + [
        (str(g), s) for g in range(1, grades + 1) for s in ("1", "2")
    ]
    sheets = pd.read_excel(io.BytesIO(body), sheet_name=None, header=None, dtype=object)
    records = []
    for sheet_name, sheet in sheets.items():
        where = f"{survey_year}年 {table_name} {sheet_name}"
        rows = [[_norm(c) for c in sheet.iloc[i].tolist()] for i in range(len(sheet))]
        grade_row = next(
            (i for i, r in enumerate(rows) if any(GRADE_RE.match(c) for c in r)), None
        )
        if grade_row is None:
            raise RuntimeError(f"{where}: 学年の見出しが無い")
        sex_row = grade_row + 1

        # 区分の列からブロックを切り出す。区分が結合セルで 2 列続く年は、続きの列を
        # 新しいブロックとみなさない。
        header = rows[grade_row]
        width = len(header)
        starts = [
            c
            for c, v in enumerate(header)
            if v == "区分" and (c == 0 or header[c - 1] != "区分")
        ] or [0]
        bounds = list(zip(starts, starts[1:] + [width], strict=True))
        grade_labels = _spread(header)

        for start, end in bounds:
            # 小学校の表は右端にも行見出しの「区分」を置く。値の列を持たないので飛ばす。
            if not any(rows[sex_row][c] in SEX_CODES for c in range(start, end)):
                continue
            # 設置者の見出しは学年の見出しより上で、このブロックの列の範囲にある。
            founders = {
                m.group(1)
                for r in rows[:grade_row]
                for c in range(start, end)
                if (m := FOUNDER_RE.match(r[c]))
            }
            if len(founders) != 1:
                raise RuntimeError(f"{where} 列{start}: 設置者が決まらない: {founders}")
            founder = founders.pop()

            columns = []
            for c in range(start, end):
                grade_label, sex = grade_labels[c], rows[sex_row][c]
                if sex not in SEX_CODES:
                    continue
                if grade_label == "計":
                    grade = "0"
                elif m := GRADE_RE.match(grade_label):
                    grade = m.group(1)
                else:
                    raise RuntimeError(f"{where}: 学年が読めない: {grade_label!r}")
                columns.append((c, grade, SEX_CODES[sex]))
            if [(g, s) for _, g, s in columns] != expected_columns:
                raise RuntimeError(
                    f"{where} {founder}: 学年と性の列がそろわない: {columns}"
                )

            first_value = columns[0][0]
            prefecture_rows: dict[int, int] = {}
            last_before = None
            for i in range(sex_row + 1, len(rows)):
                labels = [v for v in rows[i][start:first_value] if v]
                index = next(
                    (k for v in labels if (k := _prefecture_index(v)) is not None), None
                )
                if index is not None:
                    if index in prefecture_rows:
                        raise RuntimeError(
                            f"{where} {founder}: {PREFECTURES[index - 1]} が 2 行ある"
                        )
                    prefecture_rows[index] = i
                elif not prefecture_rows and NUMBER_RE.match(
                    rows[i][first_value].replace(",", "")
                ):
                    last_before = i
            if sorted(prefecture_rows) != list(range(1, len(PREFECTURES) + 1)):
                raise RuntimeError(
                    f"{where} {founder}: 都道府県が {len(prefecture_rows)} 行 (47 行のはず)"
                )
            if last_before is None:
                raise RuntimeError(f"{where} {founder}: 全国の行が無い")

            areas = [(NATIONWIDE_CODE, None, "全国", last_before)] + [
                (f"{k:02d}000", f"{k:02d}", PREFECTURES[k - 1], i)
                for k, i in sorted(prefecture_rows.items())
            ]
            for area, prefecture_code, label, i in areas:
                for c, grade, sex_code in columns:
                    records.append(
                        {
                            "survey_year": survey_year,
                            "school_type": school_type,
                            "founder_code": FOUNDERS[founder],
                            "area": area,
                            "area_label": label,
                            "prefecture_code": prefecture_code,
                            "grade": int(grade),
                            "sex_code": sex_code,
                            "students": _value(
                                rows[i][c], f"{where} {founder} {label}"
                            ),
                        }
                    )

    founders_found = {r["founder_code"] for r in records}
    if founders_found != set(FOUNDERS.values()):
        raise RuntimeError(
            f"{survey_year}年 {table_name}: 設置者がそろわない: {founders_found}"
        )
    return records


def build_school(dest_dir: str, app_id: str) -> None:
    """学年別の表を取得し、都道府県別の児童生徒数を NDJSON に整形する。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)

    records: list[dict] = []
    for survey_year, school_type, url in catalog(app_id):
        parsed = parse(_fetch(url), survey_year, school_type)
        logger.info(f"  {survey_year} {school_type}: {len(parsed)} rows")
        records += parsed

    with (dest / "enrollment_by_grade.ndjson").open("w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
    years = sorted({r["survey_year"] for r in records})
    logger.info(f"  enrollment_by_grade={len(records)} rows, {years[0]}-{years[-1]}年")
