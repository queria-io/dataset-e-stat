"""経済産業省生産動態統計 月報の統計表（確報）の取得 (getDataCatalog + 統計表 Excel)。

鉱工業の品目ごとの生産・出荷（販売）・在庫・受入・消費などを月次で取る。2022年1月から。

■ 取り込み方

e-Stat のデータベースの月次の表は 2012 年ごろまでで、今の値は月報の統計表ファイル (Excel) で
配られる。月報は毎月 1 データセットで、2022年1月分から「実数表」のシートに全調査票・全品目が
同じ形で並ぶ (2021年以前は調査票の分類ごとの印刷用の表で、形が揃わないので取らない)。
各年の最新の月のファイルがその年の 1 月から公表月までを持つ (12月分のファイルは前年12月の列も持つ)。
2022年からの全期間でも 1 年 1 ファイル・約 2MB なので、毎日の Sync で年ごとの最新のファイルを
取り直して置き換える。確報で前の月が直ることもある。

■ ファイルの形

「実数表」のシートは、2 行目が見出し (調査票番号・品目番号・アイテム記号・調査票名・項目名・品目名・
アイテム名・単位名・月の列)、1 行目の月の列の上に時間軸コード (YYYY00MMMM) がある。3 行目から
1 行が 1 アイテム (品目の生産数量・販売金額など)。「X」(秘匿) と「***」(不詳) は NULL にする。
月の列のうち、ファイルの年と違う年の列 (12月分のファイルの前年12月) は使わない。その列は翌年の
品目番号で並び、前年の年間補正を反映した値なので、前年のファイルの12月と基準が違う。前年の
12月は前年のファイルの値 (年間補正の前) を使う。

データソース: 経済産業省 経済産業省生産動態統計 (e-Stat)
https://www.e-stat.go.jp/stat-search/files?toukei=00550200
"""

import io
import json
import logging
import re
import time
import urllib.parse
from datetime import date
from http.client import IncompleteRead
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

from pipelines import EstatStatus

logger = logging.getLogger("pipelines")

CATALOG_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getDataCatalog"
STATS_CODE = "00550200"
FIRST_YEAR = 2022
SHEET = "実数表"
RESOURCE_RE = re.compile(r"_統計表_確報$")
HEADER = ["調査票番号", "品目番号", "アイテム記号", "調査票名", "項目名", "品目名", "アイテム名", "単位名"]
# 確報は翌々月の中旬に出る。最新の月が今月から4か月より前なら、差し替えが止まっている
MAX_LAG_MONTHS = 4
_UA = "dataset-e-stat"
_TIMEOUT = 300
_MAX_RETRIES = 5
_TRANSIENT_HTTP_CODES = {404, 500, 502, 503, 504}

SCHEMA = pa.schema(
    [
        ("time", pa.string()),
        ("year", pa.int16()),
        ("month", pa.int8()),
        ("form_code", pa.string()),
        ("form_name", pa.string()),
        ("category", pa.string()),
        ("product_code", pa.string()),
        ("product_name", pa.string()),
        ("item_symbol", pa.string()),
        ("item_name", pa.string()),
        ("unit", pa.string()),
        ("value", pa.float64()),
    ]
)


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
            logger.warning(f"  {getattr(e, 'reason', None) or getattr(e, 'code', None) or e}, retry in {2**attempt}s")
            time.sleep(2**attempt)
    raise RuntimeError("unreachable")


def latest_files(app_id: str) -> dict[int, tuple[int, str]]:
    """年ごとに、最新の月の月報（統計表・確報）の Excel を (月, URL) で返す。"""
    files: dict[int, tuple[int, str]] = {}
    start = 1
    while True:
        params = {
            "appId": app_id,
            "statsCode": STATS_CODE,
            "searchWord": "確報",
            "surveyYears": f"{FIRST_YEAR}01-{date.today().year}12",
            "limit": 100,
            "startPosition": start,
        }
        root = json.loads(_fetch(f"{CATALOG_URL}?{urllib.parse.urlencode(params)}"))["GET_DATA_CATALOG"]
        if root["RESULT"]["STATUS"] not in (EstatStatus.OK, EstatStatus.PARTIAL):
            raise RuntimeError(f"getDataCatalog: API error: {root['RESULT'].get('ERROR_MSG', '')}")
        listing = root["DATA_CATALOG_LIST_INF"]
        items = listing["DATA_CATALOG_INF"]
        for item in [items] if isinstance(items, dict) else items:
            title = item["DATASET"]["TITLE"]
            if title.get("TABULATION_SUB_CATEGORY1") != "確報" or title.get("CYCLE") != "月次":
                continue
            survey = int(title["SURVEY_DATE"])
            year, month = survey // 100, survey % 100
            resources = item["RESOURCES"]["RESOURCE"]
            for r in [resources] if isinstance(resources, dict) else resources:
                if RESOURCE_RE.search(r["TITLE"]["NAME"]) and r["FORMAT"] == "XLS":
                    if year not in files or month > files[year][0]:
                        files[year] = (month, r["URL"])
        next_key = listing.get("RESULT_INF", {}).get("NEXT_KEY")
        if not next_key:
            break
        if int(next_key) <= start:
            raise RuntimeError(f"getDataCatalog: NEXT_KEY {next_key} が startPosition {start} から進まない")
        start = int(next_key)
    if missing := [y for y in range(FIRST_YEAR, max(files, default=FIRST_YEAR) + 1) if y not in files]:
        raise RuntimeError(f"月報の統計表（確報）が無い年がある: {missing}")
    return files


def _number(cell) -> float | None:
    if cell is None or (isinstance(cell, float) and pd.isna(cell)):
        return None
    s = str(cell).strip()
    if s in ("X", "x", "***", "", "-"):
        return None
    return float(s)


def parse(body: bytes, year: int) -> pa.Table:
    """月報の「実数表」を縦持ちにする。ファイルの年の月だけを返す。"""
    df = pd.read_excel(io.BytesIO(body), sheet_name=SHEET, header=None, dtype=str)
    if df.iloc[1, : len(HEADER)].str.strip().tolist() != HEADER:
        raise RuntimeError(f"{year}: 実数表の見出しが想定と違う: {df.iloc[1, :len(HEADER)].tolist()}")
    months = []
    for col in range(len(HEADER), df.shape[1]):
        code = str(df.iat[0, col]).strip().removesuffix(".0")
        if re.fullmatch(r"\d{4}00\d{4}", code) and int(code[:4]) == year and pd.notna(df.iat[2, col]):
            months.append((col, code))
    if not months:
        raise RuntimeError(f"{year}: {year} 年の月の列が無い")
    body_rows = df.iloc[2:]
    body_rows = body_rows[body_rows.iloc[:, 0].astype(str).str.fullmatch(r"\d{4}")]
    records = []
    for _, row in body_rows.iterrows():
        meta = [str(v).strip() if pd.notna(v) else None for v in row.iloc[: len(HEADER)]]
        for col, code in months:
            records.append(
                {
                    "time": code,
                    "year": int(code[:4]),
                    "month": int(code[8:10]),
                    "form_code": meta[0],
                    "product_code": meta[1],
                    "item_symbol": meta[2],
                    "form_name": meta[3],
                    "category": meta[4],
                    "product_name": meta[5],
                    "item_name": meta[6],
                    "unit": meta[7],
                    "value": _number(row.iloc[col]),
                }
            )
    return pa.Table.from_pylist(records, schema=SCHEMA)


def build_production(dest_dir: str, app_id: str) -> None:
    """2022年からの年ごとの最新の月報を取り、縦持ちの Parquet に書く。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)
    parts = []
    for year, (month, url) in sorted(latest_files(app_id).items()):
        table = parse(_fetch(url), year)
        logger.info(f"  production {year} (1-{month}月): {table.num_rows} 行")
        parts.append(table)
    table = pa.concat_tables(parts)
    latest = max(table.column("time").to_pylist())
    today = date.today()
    lag = (today.year * 12 + today.month) - (int(latest[:4]) * 12 + int(latest[8:10]))
    if lag > MAX_LAG_MONTHS:
        raise RuntimeError(f"生産動態統計の最新の月が {latest} で {lag} か月遅れている")
    pq.write_table(table, dest / "monthly.parquet")
    logger.info(f"  production: {table.num_rows} 行")
