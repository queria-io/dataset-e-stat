"""介護サービス施設・事業所調査の取得 (getDataCatalog + 統計表 CSV)。

介護保険の指定を受けた施設・事業所を毎年 10 月 1 日現在で調べる調査。ここで取るのは
そのうち介護保険施設 (介護老人福祉施設 = 特別養護老人ホーム・介護老人保健施設・
介護医療院・介護療養型医療施設) の施設数と定員で、市区町村別にそろう唯一の表。
社会福祉施設等調査 (welfare_facility) にはこれらの施設は 1 行も入らない。

■ getStatsData を使わない理由

この統計は e-Stat のデータベースに 1 表も登録が無い (getStatsList を
statsCode=00450042 で呼ぶと 0 件、統計名での検索でも 0 件)。提供は統計表ファイル
だけなので、welfare_facility・local_finance と同じく getDataCatalog から辿って
CSV を読む。

■ 取り込む調査表

調査年あたりの調査表は 300 を超えるが、ここで取るのは閲覧表の
「介護保険施設数－定員，市区町村、施設の種類別」1 表だけ。ほかの表は行が
都道府県までで、市区町村の粒度を持つのはこの表しかない。

2012 年調査で基本票 (全施設) と詳細票 (回収率の影響を受ける) の 2 本立てになり、
2017 年調査まで両方が出る。2018 年調査からは基本票だけになった。2011 年調査までは
票が 1 種類しか無いので survey_form は NULL になる。

2001 年調査から取る。2000 年調査の表は行見出しに標準地域コードが無く、
市区町村名だけで突き合わせることになる。平成の大合併の前なので同名の市町村が
複数あり、名前では当てられない。

■ 表の形

CP932 の CSV で、先頭に表題と注が入り、その下に見出しが 2〜3 行重なる。行の位置は
年で変わる (2009 年調査から注の行が増えて 1 行下がる) ので、値の集合から施設の種類と
指標のどちらかに割り当てる。施設の種類の見出しは空欄を右へ送る。

常勤換算従事者数の見出しは「常勤換算」と「従事者数」の 2 行に割れているので、
指標の行は上から順に連結して 1 つの名前にする。

介護療養型医療施設の定員の見出しは、2002 年調査から「病床数」に変わる。数えている
ものは同じ枠の数なので capacity に寄せる。

■ 行

行は全国・47 都道府県・市区町村。2001〜2003 年調査には全国の行が無く、都道府県の
コードが 2 桁で入るので 5 桁に揃える。

政令指定都市とその行政区は両方の行がある。区の行を足すと市の行と二重に数えるので、
標準地域コードから段を判定して area_kind に持たせる。3 桁目が 1 のコード
(XX100〜XX199) は政令指定都市とその行政区の枠で、市の行が集計、区の行が内訳。
東京都だけは例外で、13101〜13123 の特別区が基礎自治体そのもの (集計行の
13100 特別区は 2004〜2010 年調査にだけ並ぶ)。

データソース: 厚生労働省 介護サービス施設・事業所調査
https://www.e-stat.go.jp/stat-search/files?toukei=00450042
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

from pipelines import EstatStatus, check_latest_year

logger = logging.getLogger("pipelines")

CATALOG_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getDataCatalog"
STATS_CODE = "00450042"
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

# 取り込む最初の調査年。2000 年調査は行見出しに標準地域コードが無い。
FIRST_SURVEY_YEAR = 2001
# 調査年 N の表は N+1 年 12 月〜N+2 年 1 月に出る。最新年が取れなくなったことに気づくための許容幅 (check_latest_year)。
LATEST_LAG_YEARS = 2
# 基本票と詳細票に分かれた最初の調査年。
FIRST_SPLIT_YEAR = 2012

# 市区町村別の介護保険施設の表。閲覧表の第 1 表で、表題は年で少しずつ変わる
# (「－定員（病床数）－常勤換算従事者数」「－定員（病床数）」「－定員」)。
# 同じ閲覧表に並ぶ回収率の参考表は「介護保険施設数」を含まないので外れる。
TABLE_TITLE_RE = re.compile(r"介護保険施設数.*市区町村")
FORM_MARKERS = {"基本票編": "基本票", "詳細票編": "詳細票"}

MEASURE_LABELS = {
    "施設数": "facility_count",
    # 介護療養型医療施設の定員は 2002 年調査から「病床数」の見出しで出る。
    "定員": "capacity",
    "病床数": "capacity",
    "常勤換算従事者数": "fte_workers",
}
# 常勤換算従事者数の見出しは 2 行に割れる。連結した後の名前だけを突き合わせる。
MEASURE_FRAGMENTS = {"常勤換算", "従事者数"}
BLANK_VALUES = {"", "-", "－", "…", "‥", "*", "x", "X", "・"}

# 行見出し。2001〜2003 年調査の都道府県だけ 2 桁で入る。
AREA_RE = re.compile(r"^(\d{2}|\d{5})\s+(.+)$")
NATIONWIDE_CODE = "00000"
# 東京 23 区をまとめた集計行。行見出しは「13100 特別区」で、
# 2004〜2010 年調査にだけ並ぶ。
SPECIAL_WARD_AREA_CODE = "13100"
TOKYO_PREF_CODE = "13"

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


def catalog(app_id: str) -> list[tuple[int, str | None, str]]:
    """市区町村別の表の所在を (調査年, 調査票, URL) で集める。"""
    found: dict[tuple[int, str | None], str] = {}
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
            survey_year = int(title["SURVEY_DATE"])
            if survey_year < FIRST_SURVEY_YEAR:
                continue
            # 票の区分はデータセットの名前に入る (「基本票編」「詳細票編」)。
            # 2011 年調査までは区分が無い。
            form = next(
                (f for marker, f in FORM_MARKERS.items() if marker in title["NAME"]),
                None,
            )
            resources = item["RESOURCES"]["RESOURCE"]
            if isinstance(resources, dict):
                resources = [resources]
            for res in resources:
                if res["FORMAT"] != "CSV":
                    continue
                if not TABLE_TITLE_RE.search(res["TITLE"]["NAME"]):
                    continue
                key = (survey_year, form)
                if key in found:
                    raise RuntimeError(
                        f"{survey_year}年調査の {form or '-'} に表が 2 つある"
                    )
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
        raise RuntimeError(f"getDataCatalog に {STATS_CODE} の統計表ファイルが無い")

    # 表題が変わって 1 年分だけ落ちても、ほかの年の行はそのまま残るので行数でも
    # 値でも気づけない。年の連続と、票の区分ができた年からの基本票をここで押さえる。
    years = sorted({year for year, _ in found})
    check_latest_year(years[-1], LATEST_LAG_YEARS)
    if missing := [
        year
        for year in range(FIRST_SURVEY_YEAR, years[-1] + 1)
        if year not in set(years)
    ]:
        raise RuntimeError(f"統計表が欠けている調査年: {missing}")
    if missing_basic := [
        year
        for year in range(FIRST_SPLIT_YEAR, years[-1] + 1)
        if (year, "基本票") not in found
    ]:
        raise RuntimeError(f"基本票が欠けている調査年: {missing_basic}")

    return sorted(
        ((year, form, url) for (year, form), url in found.items()),
        key=lambda t: (t[0], t[1] or ""),
    )


def _header_roles(rows: list[list[str]], width: int) -> tuple[list[int], list[str]]:
    """見出しの行番号と、各行の役割を返す。

    行の位置は年で変わる (2009 年調査から注の行が増える) ので、値の集合から
    役割を当てる。列見出しの行は 1 列目 (行見出しの列) が空で、データ行と同じ幅を持つ。
    """
    header_rows = [
        i for i, row in enumerate(rows) if len(row) == width and not _norm(row[0])
    ]
    roles = []
    for i in header_rows:
        values = {_norm(c) for c in rows[i][1:] if _norm(c)}
        if not values:
            roles.append("empty")
        elif values <= set(MEASURE_LABELS) | MEASURE_FRAGMENTS:
            roles.append("measure")
        else:
            roles.append("facility")
    if roles.count("facility") != 1:
        raise RuntimeError(f"施設の種類の見出しが 1 行ではない: {roles}")
    if "measure" not in roles:
        raise RuntimeError(f"指標の見出しが無い: {roles}")
    return header_rows, roles


def _cells(rows: list[list[str]], index: int, width: int) -> list[str]:
    row = rows[index]
    return [_norm(row[c]) if c < len(row) else "" for c in range(1, width)]


def _spread(values: list[str]) -> list[str]:
    """見出しの空欄を右へ送る。"""
    filled: list[str] = []
    carried = ""
    for value in values:
        if value:
            carried = value
        filled.append(carried)
    return filled


def _area_kind(area_code: str, area_name: str) -> str:
    """標準地域コードから、その行が集計のどの段にいるかを決める。

    3 桁目が 1 のコード (XX100〜XX199) は政令指定都市とその行政区の枠で、
    市の行が集計、区の行がその内訳。東京都の 13101〜13123 だけは特別区で、
    行政区ではなく基礎自治体そのもの。その集計行 13100 特別区は code.municipality が
    郡・振興局と同じ 'district' に置いているので、ここでも 'district' にする。
    """
    if area_code == NATIONWIDE_CODE:
        return "nationwide"
    if area_code.endswith("000"):
        return "prefecture"
    if area_code == SPECIAL_WARD_AREA_CODE:
        return "district"
    if area_code[2] != "1" or area_code.startswith(TOKYO_PREF_CODE):
        return "municipality"
    return "designated_city" if area_name.endswith("市") else "ward"


def _value(cell: str) -> float | None:
    s = _norm(cell).replace(",", "")
    if s in BLANK_VALUES:
        return None
    try:
        return float(s)
    except ValueError:
        raise RuntimeError(f"数値として読めないセル: {cell!r}") from None


def parse(body: bytes, survey_year: int, form: str | None) -> list[dict]:
    """統計表 CSV を 1 セル 1 行の縦持ちにする。"""
    rows = list(csv.reader(io.StringIO(body.decode("cp932"))))
    width = max(len(row) for row in rows)
    header_rows, roles = _header_roles(rows, width)

    facilities = _spread(_cells(rows, header_rows[roles.index("facility")], width))
    measure_rows = [
        i for i, role in zip(header_rows, roles, strict=True) if role == "measure"
    ]
    # 「常勤換算」と「従事者数」のように 2 行に割れた見出しを縦に連結する。
    measures = [
        "".join(parts)
        for parts in zip(*[_cells(rows, i, width) for i in measure_rows], strict=True)
    ]
    if unknown := {m for m in measures if m not in MEASURE_LABELS}:
        raise RuntimeError(f"{survey_year}年調査に知らない指標の見出し: {unknown}")

    last_header = max(header_rows)
    records = []
    prefectures = 0
    for row in rows[last_header + 1 :]:
        if len(row) != width or not _norm(row[0]):
            continue
        m = AREA_RE.match(row[0].replace("　", " ").strip())
        if not m:
            raise RuntimeError(f"行見出しを読めない: {row[0]!r}")
        area_code, area_name = m.group(1), _norm(m.group(2))
        if len(area_code) == 2:
            # 2001〜2003 年調査の都道府県だけ 2 桁で入る。
            area_code += "000"
        area_kind = _area_kind(area_code, area_name)
        if area_kind == "prefecture":
            prefectures += 1
        for column, (facility_type, measure) in enumerate(
            zip(facilities, measures, strict=True)
        ):
            records.append(
                {
                    "survey_year": survey_year,
                    "area_code": area_code,
                    "area_name": area_name,
                    "area_kind": area_kind,
                    "prefecture_code": (
                        None if area_kind == "nationwide" else area_code[:2]
                    ),
                    "facility_type": facility_type,
                    "survey_form": form,
                    "measure": MEASURE_LABELS[measure],
                    "value": _value(row[column + 1]),
                }
            )
    if prefectures != PREFECTURE_COUNT:
        raise RuntimeError(
            f"{survey_year}年調査の都道府県が {prefectures} 行 (47 行のはず)"
        )
    return records


def build_kaigo_service(dest_dir: str, app_id: str) -> None:
    """統計表 CSV を取得し、介護保険施設の施設数・定員を NDJSON に整形する。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)

    records: list[dict] = []
    for survey_year, form, url in catalog(app_id):
        parsed = parse(_fetch(url), survey_year, form)
        logger.info(f"  {survey_year} {form or '-'}: {len(parsed)} rows")
        records += parsed

    if not records:
        raise RuntimeError("取り込む行が 1 件も無い")

    with (dest / "insurance_facility.ndjson").open("w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")

    years = sorted({r["survey_year"] for r in records})
    logger.info(
        f"  insurance_facility={len(records)} rows, {years[0]}-{years[-1]}年調査"
    )
