"""商業動態統計調査 業種別商業販売額の時系列 (getDataCatalog + 統計表 Excel)。

経済産業省の商業動態統計調査のうち、業種別商業販売額と前年同月比（前年同月=100）を月次で取る。1980年1月から。

■ 取り込み方

e-Stat のデータベースには年報の参考表しか無く、月次の値は統計表ファイル (Excel) で配られる。
「時系列データ」のデータセットに、業種別商業販売額の全期間を 1 ファイルにまとめた Excel があり、
毎月の公表で差し替わる (速報・確報で過去の月も直る)。1 ファイル約 0.4MB なので、毎日の Sync で
取り直して置き換える。

■ ファイルの形

シート「販売額（value）(月次M)」と「前年比（change）(月次M)」を読む。どちらも 1 行が 1 か月で、
先頭列が時間軸コード (YYYY00MMMM)、次が年月、その右に業種が列で並ぶ。見出しは時間軸コードの
行の 1 つ上が業種名 (日本語)、時間軸コードの行が英語名、さらに上に単位 (10億円) がある。
「***」(集計に必要なデータが無い) と「X」(秘匿) は NULL にする。

データソース: 経済産業省 商業動態統計調査 (e-Stat)
https://www.e-stat.go.jp/stat-search/files?toukei=00550030
"""

import io
import json
import logging
import time
import urllib.parse
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
STATS_CODE = "00550030"
SUB_CATEGORY = "時系列データ"
RESOURCE_PREFIX = "業種別商業販売額及び前年"
VALUE_SHEET = "販売額（value）(月次M)"
CHANGE_SHEET = "前年比（change）(月次M)"
FIRST_TIME = "1980000101"
_UA = "dataset-e-stat"
_TIMEOUT = 300
_MAX_RETRIES = 5
_TRANSIENT_HTTP_CODES = {404, 500, 502, 503, 504}

SCHEMA = pa.schema(
    [
        ("time", pa.string()),
        ("year", pa.int16()),
        ("month", pa.int8()),
        ("business_order", pa.int8()),
        ("business", pa.string()),
        ("business_en", pa.string()),
        ("sales_billion_yen", pa.float64()),
        ("yoy_index", pa.float64()),
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


def sales_file_url(app_id: str) -> str:
    """時系列データのデータセットから、業種別商業販売額の Excel の URL を探す。"""
    params = {"appId": app_id, "statsCode": STATS_CODE, "searchWord": SUB_CATEGORY, "limit": 100}
    root = json.loads(_fetch(f"{CATALOG_URL}?{urllib.parse.urlencode(params)}"))["GET_DATA_CATALOG"]
    if root["RESULT"]["STATUS"] not in (EstatStatus.OK, EstatStatus.PARTIAL):
        raise RuntimeError(f"getDataCatalog: API error: {root['RESULT'].get('ERROR_MSG', '')}")
    items = root["DATA_CATALOG_LIST_INF"]["DATA_CATALOG_INF"]
    items = [items] if isinstance(items, dict) else items
    found = []
    for item in items:
        title = item["DATASET"]["TITLE"]
        if title.get("TABULATION_SUB_CATEGORY1") != SUB_CATEGORY:
            continue
        resources = item["RESOURCES"]["RESOURCE"]
        for r in [resources] if isinstance(resources, dict) else resources:
            if r["TITLE"]["NAME"].startswith(RESOURCE_PREFIX) and r["FORMAT"] == "XLS":
                found.append((str(title["SURVEY_DATE"]), r["URL"]))
    if not found:
        raise RuntimeError(f"{SUB_CATEGORY} のデータセットに「{RESOURCE_PREFIX}…」の Excel が無い")
    return max(found)[1]


def _parse_sheet(book: pd.ExcelFile, sheet: str) -> tuple[list[tuple[int, str, str]], pd.DataFrame]:
    """シートの業種の列 (列番号・日本語名・英語名) と、時間軸コードから下の行を返す。"""
    df = book.parse(sheet, header=None, dtype=str)
    header = df.index[df.iloc[:, 0].astype(str).str.strip() == "時間軸コード"]
    if len(header) != 1:
        raise RuntimeError(f"{sheet}: 「時間軸コード」の見出し行が見つからない")
    h = header[0]
    columns = []
    for col in range(2, df.shape[1]):
        name = df.iat[h - 1, col]
        if isinstance(name, str) and name.strip():
            columns.append((col, name.strip(), str(df.iat[h, col]).strip()))
    body = df.iloc[h + 1 :]
    body = body[body.iloc[:, 0].astype(str).str.fullmatch(r"\d{10}")]
    return columns, body


def _number(cell) -> float | None:
    if cell is None or (isinstance(cell, float) and pd.isna(cell)):
        return None
    s = str(cell).strip()
    if s in ("***", "X", "x", ""):
        return None
    return float(s)


def parse(body: bytes) -> pa.Table:
    book = pd.ExcelFile(io.BytesIO(body))
    value_cols, value_rows = _parse_sheet(book, VALUE_SHEET)
    change_cols, change_rows = _parse_sheet(book, CHANGE_SHEET)
    if [c[1] for c in value_cols] != [c[1] for c in change_cols]:
        raise RuntimeError("販売額と前年比のシートで業種の並びが違う")
    if value_rows.iloc[0, 0] != FIRST_TIME:
        raise RuntimeError(f"販売額のシートが {FIRST_TIME} から始まっていない: {value_rows.iloc[0, 0]}")
    changes = {row.iloc[0]: row for _, row in change_rows.iterrows()}
    records = []
    for _, row in value_rows.iterrows():
        code = row.iloc[0]
        change = changes.get(code)
        for order, (col, name, name_en) in enumerate(value_cols):
            records.append(
                {
                    "time": code,
                    "year": int(code[:4]),
                    "month": int(code[8:10]),
                    "business_order": order,
                    "business": name,
                    "business_en": name_en,
                    "sales_billion_yen": _number(row.iloc[col]),
                    "yoy_index": _number(change.iloc[change_cols[order][0]]) if change is not None else None,
                }
            )
    return pa.Table.from_pylist(records, schema=SCHEMA)


def build_commerce_sales(dest_dir: str, app_id: str) -> None:
    """業種別商業販売額の Excel を取り、縦持ちの Parquet に書く。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)
    table = parse(_fetch(sales_file_url(app_id)))
    pq.write_table(table, dest / "sales_by_business.parquet")
    months = len(set(table.column("time").to_pylist()))
    logger.info(f"  commerce sales_by_business: {table.num_rows} 行 ({months} か月)")
