"""学校基本調査の市町村別の表の取得 (getDataCatalog + 統計表 Excel)。

小学校・中学校の市町村別の学校数・学年別の児童生徒数・職名別の本務教員数を取る。
2021 年から毎年。都道府県別の学年別児童生徒数は pipelines/school.py (CI の Sync) が別に取る。

■ 取り込み方

年に 1 度 (12 月の確定値) しか出ず、過去の年も直らないので、CI の Sync では取らない。
load_local.py の school_municipality グループとして手元で 1 回取り、公開する。更新は
scripts/check_local_updates.py が getDataCatalog の更新日で見張る。

■ 取り込む表

学校種ごと・年ごとに 1 ファイルずつ。2022 年までは「報告書未掲載集計 市町村別集計」、
2023 年からは「学校調査票（小学校）」などの中に入る。表題は年でわずかに揺れる
(2022 年の学校数は「市町村別学校数 計、公立」、2021 年は括弧が全角)。
- 学校数: 「市町村別学校数」。設置者 (計・国立・公立・私立) × 公立の内訳 (市(区)立・町立・
  村立・組合立、中学校は都道府県立も) × 本校・分校
- 児童生徒数: 「市町村別学年別児童数 計」「市町村別学年別生徒数 計」。学年 × 男女
- 本務教員数: 「市町村別職名別教員数(本務者) 計」。職名 × 男女

設置者別 (国立・公立・私立) の児童生徒数・教員数の表もあるが、計の表だけを取る。

■ 表の形

1 ファイルに全国と 47 都道府県のシートが並ぶ。都道府県のシートは、2〜4 行目が列見出し
(上の段から下の段へ)、その下に「計」(都道府県の計) と市区町村の行が続く。市区町村の行は
1 列目が都道府県の中の 3 桁のコード (標準地域コードの下 3 桁)、2 列目が名前。政令指定都市は
区の行だけで市の行は無い。東京都には「999 東京都外」の行がある。
全国のシートは計の 1 行だけで、都道府県の計を足せば出るので読まない。

データソース: 文部科学省 学校基本調査
https://www.e-stat.go.jp/stat-search/files?toukei=00400001
"""

import io
import json
import logging
import re
import unicodedata
import urllib.parse

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

from pipelines import EstatStatus, check_latest_year
from pipelines.school import _fetch, _school_type

logger = logging.getLogger("pipelines")

CATALOG_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getDataCatalog"
STATS_CODE = "00400001"
PAGE_LIMIT = 100

# 市町村別の表が getDataCatalog に載る最初の年
FIRST_SURVEY_YEAR = 2021
# 調査年 N の確定値は N 年 12 月に出る (2025 年は 2025-12-26)。
LATEST_LAG_YEARS = 1

SCHOOL_TYPES = ("elementary", "junior_high")
# 表の種類 → 統計表の表題 (NFKC で畳み、空白を除いたもの) に当てる正規表現
TABLE_TITLE_RES = {
    "schools": re.compile(r"^市町村別学校数(計、公立)?$"),
    "students": re.compile(r"^市町村別学年別(児童|生徒)数計$"),
    "teachers": re.compile(r"^市町村別職名別教員数\(本務者\)計$"),
}
# 同じ表が Excel と閲覧用 Excel の 2 つで出る年がある。Excel を先に使う
FILE_FORMATS = ("XLS", "XLS_REP")

PREFECTURES = (
    "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県", "茨城県",
    "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県", "新潟県", "富山県",
    "石川県", "福井県", "山梨県", "長野県", "岐阜県", "静岡県", "愛知県", "三重県",
    "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県", "鳥取県", "島根県",
    "岡山県", "広島県", "山口県", "徳島県", "香川県", "愛媛県", "高知県", "福岡県",
    "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県",
)  # fmt: skip
TOTAL = "計"
MUNICIPALITY_CODE_RE = re.compile(r"^\d{3}$")
NUMBER_RE = re.compile(r"^\d+$")

GRADES = {"elementary": 6, "junior_high": 3}
SEXES = ("計", "男", "女")
POSITIONS = (
    "計", "校長", "副校長", "教頭", "主幹教諭", "指導教諭", "教諭", "助教諭", "養護教諭",
    "養護助教諭", "栄養教諭", "講師", "市町村費負担の者(再掲)",
)  # fmt: skip
# 学校数の列見出し (設置者, 公立の内訳, 本校・分校)。中学校には都道府県立が加わる
_PUBLIC_DETAILS = {
    "elementary": ("計", "市(区)立", "町立", "村立", "組合立"),
    "junior_high": ("計", "都道府県立", "市(区)立", "町立", "村立", "組合立"),
}
SCHOOL_COLUMNS = {
    school_type: {
        ("計", "計", "計"),
        ("計", "計", "本校"),
        ("計", "計", "分校"),
        ("国立", "国立", "本校"),
        *(("公立", detail, campus) for detail in details for campus in ("計", "本校", "分校")),
        ("私立", "私立", "本校"),
    }
    for school_type, details in _PUBLIC_DETAILS.items()
}

_AREA_FIELDS = [
    ("survey_year", pa.int32()),
    ("school_type", pa.string()),
    ("prefecture_name", pa.string()),
    ("municipality_code", pa.string()),
    ("municipality_name", pa.string()),
]
SCHOOLS_SCHEMA = pa.schema(
    _AREA_FIELDS
    + [
        ("founder", pa.string()),
        ("founder_detail", pa.string()),
        ("campus", pa.string()),
        ("value", pa.int64()),
    ]
)
STUDENTS_SCHEMA = pa.schema(
    _AREA_FIELDS + [("grade", pa.int32()), ("sex", pa.string()), ("value", pa.int64())]
)
TEACHERS_SCHEMA = pa.schema(
    _AREA_FIELDS + [("position", pa.string()), ("sex", pa.string()), ("value", pa.int64())]
)


def _norm(cell) -> str:
    """全角英数・全角空白を畳み、空白と改行を除く。"""
    if cell is None or (isinstance(cell, float) and pd.isna(cell)):
        return ""
    return re.sub(r"\s", "", unicodedata.normalize("NFKC", str(cell)))


def catalog_resources(app_id: str) -> list[dict]:
    """学校基本調査の統計表ファイルを集める。

    各要素は survey_year・school_type・kind (schools / students / teachers)・format・url・
    last_modified_date。取り込まない表のファイルも、統計全体の最終更新日を出すために
    last_modified_date を残す (kind が None)。
    """
    resources: list[dict] = []
    start_position = 1
    while True:
        params = urllib.parse.urlencode(
            {"appId": app_id, "statsCode": STATS_CODE, "limit": PAGE_LIMIT, "startPosition": start_position}
        )
        root = json.loads(_fetch(f"{CATALOG_URL}?{params}"))["GET_DATA_CATALOG"]
        status = root["RESULT"]["STATUS"]
        if status not in (EstatStatus.OK, EstatStatus.PARTIAL):
            raise RuntimeError(
                f"getDataCatalog: API error (status {status}): {root['RESULT'].get('ERROR_MSG', '')}"
            )

        listing = root["DATA_CATALOG_LIST_INF"]
        items = listing["DATA_CATALOG_INF"]
        for item in [items] if isinstance(items, dict) else items:
            title = item["DATASET"]["TITLE"]
            survey_year = title["SURVEY_DATE"]
            school_type = _school_type(title) if isinstance(survey_year, int) else None
            item_resources = item["RESOURCES"]["RESOURCE"]
            for res in [item_resources] if isinstance(item_resources, dict) else item_resources:
                table_name = _norm(res["TITLE"].get("TABLE_NAME", ""))
                kind = next((k for k, pattern in TABLE_TITLE_RES.items() if pattern.match(table_name)), None)
                if school_type is None or res["FORMAT"] not in FILE_FORMATS:
                    kind = None
                resources.append(
                    {
                        "survey_year": survey_year,
                        "school_type": school_type,
                        "kind": kind,
                        "format": res["FORMAT"],
                        "url": res["URL"],
                        "last_modified_date": res["LAST_MODIFIED_DATE"],
                    }
                )

        next_key = listing.get("RESULT_INF", {}).get("NEXT_KEY")
        if not next_key:
            return resources
        if int(next_key) <= start_position:
            raise RuntimeError(
                f"getDataCatalog: NEXT_KEY {next_key} が startPosition {start_position} から進まない"
            )
        start_position = int(next_key)


def catalog_modified_date(resources: list[dict]) -> str:
    """統計全体の最終更新日。scripts/check_local_updates.py と同じ定義。"""
    return max(r["last_modified_date"] for r in resources)


def catalog(resources: list[dict]) -> list[tuple[int, str, str, str]]:
    """取り込む表の所在を (調査年, 学校種, 表の種類, URL) で集める。年の連続と表のそろいを押さえる。"""
    found: dict[tuple[int, str, str], dict[str, str]] = {}
    for res in resources:
        if res["kind"] is None or res["survey_year"] < FIRST_SURVEY_YEAR:
            continue
        by_format = found.setdefault((res["survey_year"], res["school_type"], res["kind"]), {})
        if res["format"] in by_format:
            raise RuntimeError(
                f"{res['survey_year']}年 {res['school_type']} {res['kind']} に {res['format']} の表が 2 つある"
            )
        by_format[res["format"]] = res["url"]

    years = sorted({year for year, _, _ in found})
    if not years:
        raise RuntimeError("市町村別の表が見つからない")
    check_latest_year(years[-1], LATEST_LAG_YEARS)
    if missing := [
        f"{year} {school_type} {kind}"
        for year in range(FIRST_SURVEY_YEAR, years[-1] + 1)
        for school_type in SCHOOL_TYPES
        for kind in TABLE_TITLE_RES
        if (year, school_type, kind) not in found
    ]:
        raise RuntimeError(f"表が欠けている: {missing}")
    return sorted(
        (year, school_type, kind, next(urls[f] for f in FILE_FORMATS if f in urls))
        for (year, school_type, kind), urls in found.items()
    )


def _sheet_rows(body: bytes, where: str):
    """都道府県のシートごとに (都道府県名, 列見出しの組の並び, データの行の並び) を返す。

    データの行は (市区町村コード 3 桁 / 都道府県の計は None, 名前, 値の並び)。
    """
    engine = "openpyxl" if body[:2] == b"PK" else "xlrd"
    sheets = pd.read_excel(io.BytesIO(body), engine=engine, header=None, dtype=str, sheet_name=None)
    if missing := set(PREFECTURES) - set(sheets):
        raise RuntimeError(f"{where}: 都道府県のシートが無い: {sorted(missing)}")
    for prefecture in PREFECTURES:
        cells = sheets[prefecture].map(_norm)
        here = f"{where} {prefecture}"
        if cells.iat[1, 0] != prefecture:
            raise RuntimeError(f"{here}: 2 行目が都道府県名ではない: {cells.iat[1, 0]!r}")
        start = next((r for r in range(len(cells)) if cells.iat[r, 0] == TOTAL), None)
        if start is None or start < 3:
            raise RuntimeError(f"{here}: 計の行が無い")
        width = cells.shape[1]
        headers = [tuple(cells.iat[r, c] for r in range(2, start)) for c in range(2, width)]
        rows = []
        for r in range(start, len(cells)):
            code, name = cells.iat[r, 0], cells.iat[r, 1]
            if not code and not name:
                continue
            if code == TOTAL:
                code = None
            elif not MUNICIPALITY_CODE_RE.match(code):
                raise RuntimeError(f"{here} {r + 1}行目: 市区町村コードとして読めない {code!r}")
            values = []
            for c in range(2, width):
                v = cells.iat[r, c].replace(",", "")
                if not NUMBER_RE.match(v):
                    raise RuntimeError(f"{here} {name}: 数値として読めないセル {v!r}")
                values.append(int(v))
            rows.append((code, name, values))
        yield prefecture, headers, rows


def _parse(body: bytes, survey_year: int, school_type: str, where: str, expected: set, fields) -> list[dict]:
    out = []
    for prefecture, headers, rows in _sheet_rows(body, where):
        if set(headers) != expected or len(headers) != len(expected):
            raise RuntimeError(f"{where} {prefecture}: 列見出しが想定と違う: {headers}")
        for code, name, values in rows:
            for header, value in zip(headers, values, strict=True):
                out.append(
                    {
                        "survey_year": survey_year,
                        "school_type": school_type,
                        "prefecture_name": prefecture,
                        "municipality_code": code,
                        "municipality_name": None if code is None else name,
                        **fields(header),
                        "value": value,
                    }
                )
    return out


def parse_schools(body: bytes, survey_year: int, school_type: str) -> list[dict]:
    """市町村別学校数を 1 セル 1 行にする。"""
    return _parse(
        body,
        survey_year,
        school_type,
        f"{survey_year}年 {school_type} 学校数",
        SCHOOL_COLUMNS[school_type],
        lambda h: {"founder": h[0], "founder_detail": h[1], "campus": h[2]},
    )


def parse_students(body: bytes, survey_year: int, school_type: str) -> list[dict]:
    """市町村別学年別児童生徒数 (計) を 1 セル 1 行にする。学年の計は grade = 0。"""
    grades = ["計"] + [f"{g}学年" for g in range(1, GRADES[school_type] + 1)]
    return _parse(
        body,
        survey_year,
        school_type,
        f"{survey_year}年 {school_type} 児童生徒数",
        {(g, s) for g in grades for s in SEXES},
        lambda h: {"grade": grades.index(h[0]), "sex": h[1]},
    )


def parse_teachers(body: bytes, survey_year: int, school_type: str) -> list[dict]:
    """市町村別職名別教員数 (本務者、計) を 1 セル 1 行にする。"""
    return _parse(
        body,
        survey_year,
        school_type,
        f"{survey_year}年 {school_type} 本務教員数",
        {(p, s) for p in POSITIONS for s in SEXES},
        lambda h: {"position": h[0], "sex": h[1]},
    )


# load_local.py の表の名前 → (表の種類, パーサー, スキーマ)
TABLES = {
    "school_municipality_schools": ("schools", parse_schools, SCHOOLS_SCHEMA),
    "school_municipality_students": ("students", parse_students, STUDENTS_SCHEMA),
    "school_municipality_teachers": ("teachers", parse_teachers, TEACHERS_SCHEMA),
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
        parts: list[pa.Table] = []
        for survey_year, school_type, entry_kind, url in entries:
            if entry_kind != kind:
                continue
            path = files / f"{survey_year}_{school_type}_{kind}.xlsx"
            if not path.exists():
                # 書き終えてから名前を付ける。途中で止まった壊れたファイルを次の回に読まない
                tmp_file = path.with_suffix(".xlsx.tmp")
                tmp_file.write_bytes(_fetch(url))
                tmp_file.rename(path)
            parsed = parse(path.read_bytes(), survey_year, school_type)
            logger.info(f"  {name} {survey_year}年 {school_type}: {len(parsed)} 行")
            parts.append(pa.Table.from_pylist(parsed, schema=schema))
        result = pa.concat_tables(parts)
        tmp = out.with_suffix(".parquet.tmp")
        pq.write_table(result, tmp)
        tmp.rename(out)
        logger.info(f"  {name}: {result.num_rows} 行")
