"""普通貿易統計 品別国別表（全国分）の取得 (getDataCatalog + 統計表 CSV)。

財務省の普通貿易統計のうち、輸出・輸入の品別国別表（統計品目番号9桁 × 国）を、
月ごとの数量・金額の縦持ちにする。1988年から。

■ 取り込み方

品別国別表は年ごと・輸出入ごとに 1 データセットで、HS の部ごとに 22 ファイル（2008年
までは 31〜59 ファイル）の CSV に分かれる。各ファイルはその年の 1 月から公表済みの月
までを持ち、新しい月が出るたびに同じ年のデータセットが差し替わる。12月分のデータ
セットが 1 年分すべてを持つ。

- 過去の年 (local_tables.yml の trade グループの through_year まで) は、12月分の CSV を
  手元で 1 回だけ取り込む (load_local.py の fetch_local)。全期間で約 5,000 万行あり、
  毎日取り直すと Sync の時間を食うため
- それより後の年は、毎日の Sync (main.py の build_trade_recent) で年ごとの最新の
  データセットを取り直して置き換える。確報で前の月の値が直ることがあり、年の途中の
  値は置き換えないと古いまま残る

through_year を進めるときは、過去の年を取り込み直してから進める (MAINTAINING.md)。

■ CSV の形

列は「Exp or Imp, Year, HS, Country, Unit1, Unit2」のあとに、年計の
Quantity1・Quantity2・Value と、1〜12 月の Quantity1・Quantity2・Value が 3 列ずつ並ぶ。
月の列名は年で綴りが違う (1988〜2008年は Apl、2009年からは Apr) ので位置で読む。
HS は「'010121100'」のように引用符付きの 9 桁。国は 3 桁の国名コード。
金額の単位は千円。数量の単位は Unit1・Unit2 (空欄は数量なし)。

公表前の月と取引の無い月は 0 で埋まっている。数量も金額も 0 の月は行にしない。
年計の列は、月の和と一致することを確かめてから捨てる。

データソース: 財務省 貿易統計 (e-Stat)
https://www.e-stat.go.jp/stat-search/files?toukei=00350300
"""

import io
import json
import logging
import time
from datetime import date
import urllib.parse
from http.client import IncompleteRead
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.csv as pacsv
import pyarrow.parquet as pq

from pipelines import EstatStatus

logger = logging.getLogger("pipelines")

CATALOG_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getDataCatalog"
META_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getMetaInfo"
LIST_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getStatsList"
STATS_CODE = "00350300"
CATEGORY = "貿易統計_全国分"
SUB_CATEGORY = "品別国別表"
FIRST_YEAR = 1988
PAGE_LIMIT = 100
_UA = "dataset-e-stat"
_TIMEOUT = 300
_MAX_RETRIES = 5
_MAX_WAIT = 60
_TRANSIENT_HTTP_CODES = {404, 500, 502, 503, 504}

FLOWS = {"輸出": "export", "輸入": "import"}

SCHEMA = pa.schema(
    [
        ("flow", pa.string()),
        ("year", pa.int16()),
        ("month", pa.int8()),
        ("hs_code", pa.string()),
        ("country_code", pa.string()),
        ("unit1", pa.string()),
        ("unit2", pa.string()),
        ("quantity1", pa.int64()),
        ("quantity2", pa.int64()),
        ("value", pa.int64()),
        ("release", pa.string()),
    ]
)
SORT_KEYS = [("hs_code", "ascending"), ("country_code", "ascending"), ("flow", "ascending"), ("year", "ascending"), ("month", "ascending")]


def _fetch(url: str) -> bytes:
    """再試行付きで URL を取得する。統計表ファイルの配信は、存在する URL にも 404 を返す窓を持つ。"""
    for attempt in range(_MAX_RETRIES):
        try:
            with urlopen(Request(url, headers={"User-Agent": _UA}), timeout=_TIMEOUT) as resp:
                return resp.read()
        except (HTTPError, URLError, TimeoutError, ConnectionResetError, IncompleteRead) as e:
            transient = not isinstance(e, HTTPError) or e.code in _TRANSIENT_HTTP_CODES
            if not transient or attempt == _MAX_RETRIES - 1:
                raise
            wait = min(2**attempt, _MAX_WAIT)
            logger.warning(f"  {getattr(e, 'reason', None) or getattr(e, 'code', None) or e}, retry in {wait}s")
            time.sleep(wait)
    raise RuntimeError("unreachable")


def _api(url: str, params: dict) -> dict:
    return json.loads(_fetch(f"{url}?{urllib.parse.urlencode(params)}"))


def catalog_datasets(app_id: str, first_year: int | None = None, last_year: int | None = None) -> list[dict]:
    """品別国別表（全国分）のデータセットを集める。年・輸出入・公表済みの月とファイルの一覧。

    貿易統計のファイルは 1,700 データセットあり、絞らずに一覧すると 8 分かかる。
    表の名前（searchWord）で約 1.5 分、さらに年（surveyYears）で絞ると数秒になる。
    """
    datasets: list[dict] = []
    params = {"appId": app_id, "statsCode": STATS_CODE, "dataType": "CSV", "searchWord": SUB_CATEGORY, "limit": PAGE_LIMIT}
    if first_year is not None:
        params["surveyYears"] = f"{first_year}01-{last_year or date.today().year}12"
    start = 1
    while True:
        root = _api(CATALOG_URL, {**params, "startPosition": start})["GET_DATA_CATALOG"]
        status = root["RESULT"]["STATUS"]
        if status not in (EstatStatus.OK, EstatStatus.PARTIAL):
            raise RuntimeError(f"getDataCatalog: API error (status {status}): {root['RESULT'].get('ERROR_MSG', '')}")
        listing = root["DATA_CATALOG_LIST_INF"]
        items = listing["DATA_CATALOG_INF"]
        for item in [items] if isinstance(items, dict) else items:
            title = item["DATASET"]["TITLE"]
            if title["TABULATION_CATEGORY"] != CATEGORY or title["TABULATION_SUB_CATEGORY1"] != SUB_CATEGORY:
                continue
            flow = next((v for k, v in FLOWS.items() if f"_{k}_" in title["NAME"]), None)
            if flow is None:
                raise RuntimeError(f"輸出か輸入かが読めない: {title['NAME']}")
            resources = item["RESOURCES"]["RESOURCE"]
            resources = [resources] if isinstance(resources, dict) else resources
            survey = int(title["SURVEY_DATE"])
            datasets.append(
                {
                    "year": survey // 100,
                    "month": survey % 100,
                    "flow": flow,
                    "files": [
                        {
                            "name": r["TITLE"]["NAME"],
                            "release": r["TITLE"].get("TABLE_CATEGORY", ""),
                            "url": r["URL"],
                            "last_modified_date": r["LAST_MODIFIED_DATE"],
                        }
                        for r in resources
                    ],
                }
            )
        next_key = listing.get("RESULT_INF", {}).get("NEXT_KEY")
        if not next_key:
            break
        if int(next_key) <= start:
            raise RuntimeError(f"getDataCatalog: NEXT_KEY {next_key} が startPosition {start} から進まない")
        start = int(next_key)
    if not datasets:
        raise RuntimeError(f"getDataCatalog に {SUB_CATEGORY} のデータセットが無い")
    return datasets


def latest_by_year(datasets: list[dict]) -> dict[tuple[int, str], dict]:
    """年・輸出入ごとに、最も新しい月のデータセットを選ぶ。"""
    latest: dict[tuple[int, str], dict] = {}
    for d in datasets:
        key = (d["year"], d["flow"])
        if key not in latest or d["month"] > latest[key]["month"]:
            latest[key] = d
    return latest


def catalog_modified_date(datasets: list[dict], through_year: int) -> str:
    """through_year までの年のファイルの最終更新日の最大。

    scripts/check_local_updates.py が catalog_filter で同じ定義を使う。
    """
    return max(
        f["last_modified_date"] for d in datasets if d["year"] <= through_year for f in d["files"]
    )


def parse_csv(body: bytes, flow: str, year: int, release: str) -> pa.Table:
    """品別国別表の CSV 1 つを、数量か金額が 0 でない月だけの縦持ちにする。"""
    raw = pacsv.read_csv(
        io.BytesIO(body),
        read_options=pacsv.ReadOptions(encoding="cp932"),
        convert_options=pacsv.ConvertOptions(strings_can_be_null=False, column_types={"HS": pa.string(), "Country": pa.string(), "Unit1": pa.string(), "Unit2": pa.string()}),
    )
    names = raw.column_names
    if len(names) != 9 + 12 * 3 or names[:6] != ["Exp or Imp", "Year", "HS", "Country", "Unit1", "Unit2"]:
        raise RuntimeError(f"{year} {flow}: 列の並びが想定と違う: {names[:9]} … ({len(names)} 列)")
    if raw.num_rows == 0:
        return SCHEMA.empty_table()
    expected_flow = {"export": 1, "import": 2}[flow]
    flows = pc.unique(raw.column("Exp or Imp")).to_pylist()
    years = pc.unique(raw.column("Year")).to_pylist()
    if flows != [expected_flow] or years != [year]:
        raise RuntimeError(f"{year} {flow}: ファイルの輸出入 {flows} か年 {years} が違う")

    hs = pc.utf8_trim(raw.column("HS"), "' ")
    if not pc.all(pc.match_substring_regex(hs, r"^[0-9A-Z]{9}$")).as_py():
        raise RuntimeError(f"{year} {flow}: 9 文字の英数字でない HS がある")
    country = pc.utf8_lpad(pc.utf8_trim_whitespace(pc.cast(raw.column("Country"), pa.string())), 3, "0")
    unit1 = pc.if_else(pc.equal(pc.utf8_trim_whitespace(raw.column("Unit1")), ""), None, pc.utf8_trim_whitespace(raw.column("Unit1")))
    unit2 = pc.if_else(pc.equal(pc.utf8_trim_whitespace(raw.column("Unit2")), ""), None, pc.utf8_trim_whitespace(raw.column("Unit2")))

    def num(i: int) -> pa.Array:
        return pc.cast(raw.column(i), pa.int64())

    # 年計 = 月の和 を確かめる。崩れていれば列の位置の読み違い
    for k in range(3):
        months = num(9 + k)
        for m in range(1, 12):
            months = pc.add(months, num(9 + 3 * m + k))
        if not pc.all(pc.equal(months, num(6 + k))).as_py():
            raise RuntimeError(f"{year} {flow}: {names[6 + k]} が月の和と一致しない")

    parts = []
    for m in range(12):
        q1, q2, v = num(9 + 3 * m), num(10 + 3 * m), num(11 + 3 * m)
        keep = pc.or_(pc.or_(pc.not_equal(q1, 0), pc.not_equal(q2, 0)), pc.not_equal(v, 0))
        part = pa.table(
            {
                "flow": pa.array([flow] * raw.num_rows, pa.string()),
                "year": pa.array([year] * raw.num_rows, pa.int16()),
                "month": pa.array([m + 1] * raw.num_rows, pa.int8()),
                "hs_code": hs,
                "country_code": country,
                "unit1": unit1,
                "unit2": unit2,
                "quantity1": q1,
                "quantity2": q2,
                "value": v,
                "release": pa.array([release] * raw.num_rows, pa.string()),
            },
            schema=SCHEMA,
        )
        parts.append(part.filter(keep))
    return pa.concat_tables(parts)


def fetch_dataset(dataset: dict, files_dir: Path | None = None) -> pa.Table:
    """データセットのファイルをすべて取り、1 つの表にする。files_dir があればそこにも残し、次はそこから読む。"""
    parts = []
    for i, f in enumerate(dataset["files"]):
        path = files_dir / f"{dataset['year']}_{dataset['flow']}_{i:02d}.csv" if files_dir else None
        if path is not None and path.exists():
            body = path.read_bytes()
        else:
            body = _fetch(f["url"])
            if path is not None:
                tmp = path.with_suffix(".csv.tmp")
                tmp.write_bytes(body)
                tmp.rename(path)
        parts.append(parse_csv(body, dataset["flow"], dataset["year"], f["release"]))
    table = pa.concat_tables(parts)
    logger.info(f"  {dataset['year']} {dataset['flow']} (1-{dataset['month']}月): {table.num_rows} 行")
    return table


def country_names(app_id: str) -> pa.Table:
    """国名コードと国名。CSV には国名が無いので、データベースの品別国別表の地域軸から引く。

    国名コードは年で廃止・新設がある。古い表から新しい表の順に読み、同じコードは新しい名前で上書きする。
    """
    root = _api(LIST_URL, {"appId": app_id, "statsCode": STATS_CODE, "searchWord": "品別国別表", "limit": 1000})
    tables = root["GET_STATS_LIST"]["DATALIST_INF"]["TABLE_INF"]
    tables = [tables] if isinstance(tables, dict) else tables

    def title(t):
        x = t["TITLE"]
        return x.get("$", "") if isinstance(x, dict) else x

    targets = sorted(
        (t for t in tables if title(t).split()[1:2] == ["品別国別表"] or " 品別国別表 " in f" {title(t)} "),
        key=lambda t: t.get("SURVEY_DATE") or "",
    )
    names: dict[str, str] = {}
    for t in targets:
        meta = _api(META_URL, {"appId": app_id, "statsDataId": t["@id"]})["GET_META_INFO"]["METADATA_INF"]
        for obj in meta["CLASS_INF"]["CLASS_OBJ"]:
            if obj["@id"] != "area":
                continue
            for c in obj["CLASS"] if isinstance(obj["CLASS"], list) else [obj["CLASS"]]:
                code, _, name = c["@name"].partition("_")
                if code.isdigit() and name:
                    names[code.zfill(3)] = name
    if len(names) < 200:
        raise RuntimeError(f"国名が {len(names)} 件しか取れない")
    logger.info(f"  国名: {len(names)} 件 ({len(targets)} 表から)")
    return pa.table({"country_code": list(names), "country_name": list(names.values())})


def fetch_local(app_id: str, spec: dict, cache_path) -> None:
    """load_local.py の fetch。through_year までの年の 12 月分を取り、cache_path(表) の Parquet を書く。"""
    through_year = int(spec["catalog_filter"]["through_year"])
    datasets = catalog_datasets(app_id, first_year=FIRST_YEAR, last_year=through_year)
    modified = catalog_modified_date(datasets, through_year)
    if modified != str(spec["catalog_modified_date"]):
        raise SystemExit(
            f"e-Stat の最終更新日 {modified} が local_tables.yml の "
            f"{spec['catalog_modified_date']} と違う。yml を直してから取り直す"
        )
    latest = latest_by_year(datasets)
    for table_spec in spec["tables"]:
        out = cache_path(table_spec)
        if out.exists():
            logger.info(f"  {table_spec['name']}: 取得済み")
            continue
        if table_spec["name"] == "trade_country":
            table = country_names(app_id)
        elif table_spec["name"] == "trade_history":
            files = out.parent / "files" / modified
            files.mkdir(parents=True, exist_ok=True)
            parts = []
            for year in range(FIRST_YEAR, through_year + 1):
                for flow in ("export", "import"):
                    d = latest.get((year, flow))
                    if d is None or d["month"] != 12:
                        raise RuntimeError(f"{year} {flow} の 12 月分のデータセットが無い")
                    parts.append(fetch_dataset(d, files))
            # HS コード順に並べる。品目で絞る問い合わせが、行グループの統計で読む範囲を絞れる
            table = pa.concat_tables(parts).sort_by(SORT_KEYS)
        else:
            raise SystemExit(f"trade グループに無い表: {table_spec['name']}")
        tmp = out.with_suffix(".parquet.tmp")
        pq.write_table(table, tmp)
        tmp.rename(out)
        logger.info(f"  {table_spec['name']}: {table.num_rows} 行")


def build_trade_recent(dest_dir: str, app_id: str, through_year: int) -> None:
    """through_year より後の年を、年・輸出入ごとの最新のデータセットから取り、Parquet に書く。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)
    latest = latest_by_year(catalog_datasets(app_id, first_year=through_year + 1))
    years = sorted({y for y, _ in latest if y > through_year})
    if not years:
        raise RuntimeError(f"{through_year} 年より後の品別国別表が無い")
    parts = []
    for year in years:
        for flow in ("export", "import"):
            d = latest.get((year, flow))
            if d is None:
                raise RuntimeError(f"{year} {flow} のデータセットが無い")
            parts.append(fetch_dataset(d))
    table = pa.concat_tables(parts).sort_by(SORT_KEYS)
    pq.write_table(table, dest / "recent.parquet")
    logger.info(f"  trade recent: {table.num_rows} 行 ({years[0]}-{years[-1]}年)")
