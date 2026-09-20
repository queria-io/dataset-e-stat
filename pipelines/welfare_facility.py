"""社会福祉施設等調査の取得 (getDataCatalog + 統計表 CSV)。

保育所・障害者支援施設・児童養護施設・養護老人ホームなどの施設数・定員・
在所者数・従事者数を、都道府県別・施設の種類別に毎年調べる全数調査
(詳細票のみ標本)。特別養護老人ホームなど介護保険の施設は別の調査
(介護サービス施設・事業所調査) の対象で、この統計には入らない。

■ getStatsData を使わない理由

この統計は e-Stat のデータベースに 1 表も登録が無い (getStatsList を
statsCode=00450041 で呼ぶと 0 件、統計名での検索でも 0 件)。提供は統計表
ファイルだけなので、getDataCatalog から辿って CSV を読む。

■ 取り込む調査表

年度あたりの調査表は 200 を超えるが、ここで取るのは「個別表 施設票」の
4 表だけ。いずれも行が国・都道府県、列が施設の種類 × 経営主体で、
4 つの指標がそのまま都道府県 × 施設の種類 × 年でそろう。

- 施設数        第 1 表 (H01K)      基本票
- 定員          第 7/8 表 (H0nK)    基本票
- 定員・在所者数 第 7/8 表 (H0nS)    詳細票
- 常勤換算従事者数 第 13/14 表 (H13) 詳細票

2012 年調査で基本票 (全施設) と詳細票 (一部は標本) の 2 本立てになった。
定員は両方の票にあり、母集団が違うので survey_form で分ける。2011 年調査は
票が 1 種類しか無いので survey_form は NULL になる。

詳細票から施設数を出す表 (H01S) は 2012・2013 年調査にしか無い。2 年分だけの
系列を混ぜると survey_form で絞ったときに年が飛ぶので取らない。

■ 表の形

CP932 の CSV で、先頭に表題と注が入り、その下に見出しが 3〜6 行重なる。
見出しの行数も役割も年で変わる (2011 年調査は施設の種類が 1 行、2015 年調査
以降は 3 行、2023 年調査から単位の行が増える) ので、行の位置では読まない。
各行の値の集合を見て、経営主体・指標・単位・施設の種類のどれかに割り当てる。

施設の種類の見出しは年によって空欄を送るものと、e-Stat 側で前送り済みのものが
ある。前送りは親の値が変わったところで打ち切る。打ち切らないと、子を持たない
施設の種類に直前の子の名前が付く。

■ 行

行は全国・国・47 都道府県。2017 年調査までは、その下に指定都市と中核市の行が
続く。

この別掲は再掲ではない。調査の実施主体が都道府県・指定都市・中核市に分かれて
いて、都道府県の行はその県から指定都市・中核市を除いた分しか持たない (実測:
2017 年調査の基本票の定員は全国 3,875,461 = 国 1,308 + 都道府県 2,511,610 +
指定都市 783,741 + 中核市 578,802)。2018 年調査からは市の行が無くなり、
都道府県の行が県全体になる。

そのため都道府県の値をそのまま 2011 年から並べると 2018 年に段差ができる。
市の行も落とさずに取り込み、どの県に属するかを prefecture_code で持たせて、
足し合わせれば通しで見られるようにする。

都道府県名は 2022 年調査まで「青森」、2023 年調査から「青森県」と表記が変わる。
接尾辞は stg で補って code.municipality の pref_name に合わせる。

データソース: 厚生労働省 社会福祉施設等調査
https://www.e-stat.go.jp/stat-search/files?toukei=00450041
"""

import csv
import io
import json
import logging
import re
import time
import urllib.parse
from http.client import IncompleteRead
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from pipelines import EstatStatus

logger = logging.getLogger("pipelines")

CATALOG_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getDataCatalog"
STATS_CODE = "00450041"
_UA = "dataset-e-stat"
_TIMEOUT = 300
# local_finance と同じ理由。統計表ファイルの配信は、存在する URL に対しても
# 404 を返す窓を持つので、404 も一時障害として待つ。
_TRANSIENT_HTTP_CODES = {404, 500, 502, 503, 504}
_MAX_RETRIES = 8
_MAX_WAIT = 30
_MAX_NETWORK_RETRIES = 4
# getDataCatalog の 1 リクエストあたり上限。超えると status 102 で弾かれる。
PAGE_LIMIT = 100

# 取り込む最初の調査年。2010 年調査までは 1 つの指標が施設の種類の範囲で
# 2〜4 ファイルに割れており、割れ方も年ごとに違う。
FIRST_SURVEY_YEAR = 2011

# 見出しの語。年によって全角空白が入るので、突き合わせる前に落とす。
OPERATORS = {"総数", "公営", "私営"}
MEASURE_LABELS = {"定員": "capacity", "在所者数": "occupants"}
UNIT_LABELS = {"人", "施設・事業所", "世帯"}
NATIONWIDE = "全国"
STATE = "国"
# 市の行が始まる見出し。この行自体は値を持たず、次の見出しまでが市の行。
CITY_BLOCKS = {
    "指定都市（別掲）": "designated_city",
    "指定都市(別掲)": "designated_city",
    "中核市（別掲）": "core_city",
    "中核市(別掲)": "core_city",
}

# 表題から拾う表の識別子と、そこから決まる指標・調査票。
# 2011 年調査だけ H が付かない通し番号で、票の区分もまだ無い。
TABLE_PATTERNS = [
    (re.compile(r"^(【基本票】)?社会福祉施設等数，国[－―]都道府県"), "facility_count"),
    (
        re.compile(r"^(【基本票】)?社会福祉施設等の定員(数)?，国[－―]都道府県"),
        "capacity",
    ),
    (
        re.compile(r"^(【詳細票】)?社会福祉施設等の定員・在所者数，国[－―]都道府県"),
        "capacity_occupants",
    ),
    (re.compile(r"^社会福祉施設等の常勤換算従事者数，国[－―]都道府県"), "fte_workers"),
]
# 表番号の接尾辞が調査票を表す。K=基本票、S=詳細票。従事者数は接尾辞を持たないが
# 「詳細票の調査を実施していない施設は除く」と注記があるので詳細票。
TABLE_NO_RE = re.compile(r"^(H?\d+)([KS]?)_")
FORM_BY_SUFFIX = {"K": "基本票", "S": "詳細票"}
# 表の識別子 -> 調査票。接尾辞を持たない表はここで決める。
FORM_BY_KIND = {"fte_workers": "詳細票"}
# 2012・2013 年調査にしか無い詳細票の施設数。系列がそこだけになるので取らない。
EXCLUDED_TABLE_NOS = {"H01S"}

FACILITY_CODE_RE = re.compile(r"^(\d{4})(.+)$")
# 再掲の列。ほかの列に含まれている分の再掲なので、足すと二重に数える。
REPRINT_PREFIX = re.compile(r"^[（(]再掲[）)]")

PREFECTURE_COUNT = 47


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


def _norm(cell: str) -> str:
    return cell.replace("　", "").replace(" ", "").strip()


def catalog(app_id: str) -> list[tuple[int, str, str, str, str]]:
    """統計表ファイルの所在を (調査年, 表番号, 指標, 調査票, URL) で集める。"""
    found: dict[tuple[int, str], tuple[int, str, str, str, str]] = {}
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
            # 個別表の施設票だけが都道府県 × 施設の種類の形。閲覧表にも似た表題の
            # 表があるが、そちらは苦情解決の取組状況などの軸が 1 つ増えている。
            if "個別表" not in title["NAME"] or "施設票" not in title["NAME"]:
                continue
            survey_year = int(title["SURVEY_DATE"])
            if survey_year < FIRST_SURVEY_YEAR:
                continue
            resources = item["RESOURCES"]["RESOURCE"]
            if isinstance(resources, dict):
                resources = [resources]
            for res in resources:
                if res["FORMAT"] != "CSV":
                    continue
                name = res["TITLE"]["NAME"]
                m = TABLE_NO_RE.match(name)
                if not m:
                    continue
                table_no, suffix = m.group(1) + m.group(2), m.group(2)
                if table_no in EXCLUDED_TABLE_NOS:
                    continue
                body = name.split("_", 1)[1].strip()
                kind = next(
                    (k for pattern, k in TABLE_PATTERNS if pattern.match(body)), None
                )
                if kind is None:
                    continue
                # 票の区分は 2012 年調査から。表番号に H が付くのがその年以降で、
                # 2011 年調査は通し番号のまま票が 1 種類しか無い。
                form = FORM_BY_SUFFIX.get(suffix)
                if form is None and table_no.startswith("H"):
                    form = FORM_BY_KIND.get(kind)
                key = (survey_year, kind)
                if key in found:
                    raise RuntimeError(
                        f"{survey_year}年調査の {kind} に表が 2 つある: "
                        f"{found[key][1]} と {table_no}"
                    )
                found[key] = (survey_year, table_no, kind, form, res["URL"])

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
        raise RuntimeError(f"getDataCatalog に {STATS_CODE} の統計表ファイルが無い")

    # 4 つの表は 2011 年調査から毎年そろっている。1 つでも取れなくなったら止める。
    # 表題や区分の文言が変わると該当の表だけが黙って落ち、ほかの指標の行はそのまま
    # 残るので、行数でも年の連続でも気づけない。
    years = sorted({year for year, _ in found})
    expected = {
        (year, kind)
        for year in range(FIRST_SURVEY_YEAR, years[-1] + 1)
        for kind in {k for _, k in TABLE_PATTERNS}
    }
    if missing := expected - set(found):
        raise RuntimeError(f"統計表が欠けている調査年・指標: {sorted(missing)}")

    return sorted(found.values())


def _header_roles(rows: list[list[str]], width: int) -> tuple[list[int], list[str]]:
    """見出しの行番号と、各行の役割を返す。

    行の位置は年ごとに変わるので、値の集合から役割を当てる。列見出しの行は
    1 列目 (行見出しの列) が空で、データ行と同じ幅を持つ。
    """
    header_rows = [
        i for i, row in enumerate(rows) if len(row) == width and not _norm(row[0])
    ]
    roles = []
    for i in header_rows:
        values = {_norm(c) for c in rows[i][1:] if _norm(c)}
        if not values:
            roles.append("empty")
        elif values <= set(MEASURE_LABELS):
            roles.append("measure")
        elif values <= OPERATORS:
            roles.append("operator")
        elif values <= UNIT_LABELS:
            roles.append("unit")
        else:
            roles.append("facility")
    if roles.count("operator") != 1:
        raise RuntimeError(f"経営主体の見出しが 1 行ではない: {roles}")
    if not any(r == "facility" for r in roles):
        raise RuntimeError(f"施設の種類の見出しが無い: {roles}")
    return header_rows, roles


def _spread(values: list[str], parent: list[str] | None) -> list[str]:
    """見出しの空欄を右へ送る。親の値が変わったところで打ち切る。

    打ち切らないと、子の区分を持たない施設の種類に直前の子の名前が付く。
    """
    filled: list[str] = []
    carried = ""
    for i, value in enumerate(values):
        if parent is not None and i > 0 and parent[i] != parent[i - 1]:
            carried = ""
        if value:
            carried = value
        filled.append(carried)
    return filled


def _facility_paths(
    rows: list[list[str]], header_rows: list[int], roles: list[str], width: int
) -> list[list[str]]:
    """列ごとに、施設の種類の見出しを浅い段から並べる。

    見出しは年によって 1〜3 段。空欄は右へ送るが、親の値が変わったところで
    打ち切る。打ち切らないと、子の区分を持たない施設の種類に直前の子の名前が付く。
    """
    levels: list[list[str]] = []
    parent: list[str] | None = None
    for i, role in zip(header_rows, roles, strict=True):
        if role != "facility":
            continue
        raw = [_norm(rows[i][c]) if c < len(rows[i]) else "" for c in range(1, width)]
        parent = _spread(raw, parent)
        levels.append(parent)

    paths = []
    for column in range(width - 1):
        path: list[str] = []
        for level in levels:
            value = level[column]
            if value and (not path or path[-1] != value):
                path.append(value)
        paths.append([v for v in path if v != "総数"])
    return paths


def _facility_axis(
    paths: list[list[str]], groups: set[str]
) -> list[dict[str, str | None]]:
    """列ごとに施設の種類の位置を組み立てる。

    一番深い値をその列の施設の種類とし、4 桁の符号が付いていれば切り出す。

    足し合わせて全体の総数になる段を facility_level = 'type' に分ける。符号を持つ
    列はすべてこの段で、符号を持たない列のうち大分類の小計 ('group') と、保育所等を
    認定こども園と保育所に割った内訳 ('detail')、それに再掲 ('reprint') は外れる。
    2024 年調査の女性自立支援施設のように、符号も下の段も持たないまま一番上の段に
    並ぶ施設の種類があるので、符号の有無だけでは分けられない。

    大分類の名前 (groups) は全ファイルから集めて渡す。定員・在所者数の表は
    2014 年調査まで段が 1 つしか無く、その表の中だけでは大分類と施設の種類を
    見分けられない (婦人保護施設はそこでは符号を持たない)。
    """
    axis = []
    for named in paths:
        code, facility_type = _split_code(named[-1] if named else "総数")
        _, parent = _split_code(named[-2]) if len(named) >= 2 else (None, None)
        _, group = _split_code(named[0]) if len(named) >= 2 else (None, None)
        if facility_type == "総数":
            level_kind = "total"
        elif REPRINT_PREFIX.match(facility_type):
            level_kind = "reprint"
        elif code:
            level_kind = "type"
        elif named[-1] in groups:
            level_kind = "group"
        elif parent is None:
            level_kind = "type"
        else:
            level_kind = "detail"
        axis.append(
            {
                "facility_code": code,
                "facility_type": facility_type,
                "facility_parent": parent,
                "facility_group": group,
                "facility_level": level_kind,
            }
        )
    return axis


def _split_code(label: str) -> tuple[str | None, str]:
    m = FACILITY_CODE_RE.match(label)
    return (m.group(1), m.group(2)) if m else (None, label)


def _spread_simple(rows: list[list[str]], index: int, width: int) -> list[str]:
    filled: list[str] = []
    carried = ""
    for c in range(1, width):
        value = _norm(rows[index][c]) if c < len(rows[index]) else ""
        if value:
            carried = value
        filled.append(carried)
    return filled


def _value(cell: str) -> float | None:
    s = _norm(cell).replace(",", "")
    if not s or s in {"-", "－", "…", "‥", "*", "x", "X", "・"}:
        return None
    try:
        return float(s)
    except ValueError:
        raise RuntimeError(f"数値として読めないセル: {cell!r}") from None


def _read(body: bytes) -> tuple[list[list[str]], int, list[int], list[str]]:
    rows = list(csv.reader(io.StringIO(body.decode("cp932"))))
    width = max(len(row) for row in rows)
    header_rows, roles = _header_roles(rows, width)
    return rows, width, header_rows, roles


def group_labels(body: bytes) -> set[str]:
    """その表で下に段を持っている施設の種類 (大分類) の名前を返す。"""
    rows, width, header_rows, roles = _read(body)
    paths = _facility_paths(rows, header_rows, roles, width)
    return {_split_code(path[i])[1] for path in paths for i in range(len(path) - 1)}


def parse(
    body: bytes, survey_year: int, kind: str, form: str | None, groups: set[str]
) -> list[dict]:
    """統計表 CSV を 1 セル 1 行の縦持ちにする。"""
    rows, width, header_rows, roles = _read(body)
    axis = _facility_axis(_facility_paths(rows, header_rows, roles, width), groups)

    operator_row = header_rows[roles.index("operator")]
    operators = _spread_simple(rows, operator_row, width)
    if "measure" in roles:
        measures = _spread_simple(rows, header_rows[roles.index("measure")], width)
    else:
        measures = [kind] * (width - 1)

    last_header = max(header_rows)
    data_rows = [
        row
        for i, row in enumerate(rows)
        if i > last_header and len(row) == width and _norm(row[0])
    ]
    labels = [_norm(row[0]) for row in data_rows]
    if labels[:2] != [NATIONWIDE, STATE]:
        raise RuntimeError(f"行の並びが全国・国で始まらない: {labels[:3]}")

    kinds = ["nationwide", "state"]
    current = "prefecture"
    for label in labels[2:]:
        block = CITY_BLOCKS.get(label)
        if block:
            current = block
        kinds.append(block and "block_header" or current)
    if kinds.count("prefecture") != PREFECTURE_COUNT:
        raise RuntimeError(
            f"都道府県の行が {kinds.count('prefecture')} 行 (47 行のはず): "
            f"{labels[2:5]}…{labels[-3:]}"
        )

    records = []
    for row, area_label, area_kind in zip(data_rows, labels, kinds, strict=True):
        if area_kind == "block_header":
            # 「指定都市（別掲）」の行自体は見出しで、値を持たない。
            continue
        for column, facility in enumerate(axis):
            records.append(
                {
                    "survey_year": survey_year,
                    "area_kind": area_kind,
                    "area_label": area_label,
                    **facility,
                    "operator": operators[column],
                    "survey_form": form,
                    "measure": MEASURE_LABELS.get(measures[column], measures[column]),
                    "value": _value(row[column + 1]),
                }
            )
    return records


def build_welfare_facility(dest_dir: str, app_id: str) -> None:
    """統計表 CSV を取得し、施設数・定員・在所者数・従事者数を NDJSON に整形する。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)

    tables = [
        (survey_year, table_no, kind, form, _fetch(url))
        for survey_year, table_no, kind, form, url in catalog(app_id)
    ]
    # 大分類の名前は全表から集める。定員・在所者数の表は 2014 年調査まで段が
    # 1 つしか無く、その表だけでは大分類と施設の種類を見分けられない。
    groups: set[str] = set()
    for *_, body in tables:
        groups |= group_labels(body)

    records: list[dict] = []
    for survey_year, table_no, kind, form, body in tables:
        parsed = parse(body, survey_year, kind, form, groups)
        logger.info(f"  {survey_year} {table_no} {kind}: {len(parsed)} rows")
        records += parsed

    if not records:
        raise RuntimeError("取り込む行が 1 件も無い")

    with (dest / "facility_statistics.ndjson").open("w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")

    years = sorted({r["survey_year"] for r in records})
    logger.info(
        f"  facility_statistics={len(records)} rows, {years[0]}-{years[-1]}年調査"
    )
