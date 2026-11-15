"""統計表ファイル (Excel・CSV) の取得の記録 (source_file)。

ファイルで配られる統計を取るパイプラインは、取得したファイルの一覧を主題ごとの
source_file テーブルにし、raw の各行に元のファイルの sha256 (source_sha256) を持たせる。
1 行が 1 つのファイルで、同じ URL でも中身が変われば別の行にする。前のバージョンの
一覧に、今回取得して中身が変わったファイルの行を足していく。

ファイル本体は保存しない。e-Stat の統計表ファイルは URL から取得し直せる。
列の形は dataset-shared の README「元のファイル」。
"""

import logging
import os
import time
from pathlib import Path
from urllib.error import HTTPError

import pyarrow as pa
import pyarrow.parquet as pq

from shared.fetch import fetch_file

logger = logging.getLogger("pipelines")

USER_AGENT = "dataset-e-stat"
# 統計表ファイルの配信は、存在する URL にも 404 を返す窓を持つ
_NOT_FOUND_RETRIES = 5

SCHEMA = pa.schema(
    [
        ("url", pa.string()),
        ("page_url", pa.string()),
        ("sha256", pa.string()),
        ("bytes", pa.int64()),
        ("media_type", pa.string()),
        # fetch_file が返す ISO 8601 の文字列のまま持ち、stg で TIMESTAMPTZ にする
        ("retrieved_at", pa.string()),
        ("etag", pa.string()),
        ("last_modified", pa.string()),
    ]
)


def previous_rows(schema: str) -> list[dict]:
    """前のバージョンの <schema>.source_file。fdl checkout した作業中のカタログから読む。"""
    working = os.environ.get("FDL_WORKING")
    if not working:
        logger.info(f"  {schema}: FDL_WORKING が無いので、前のバージョンのファイル一覧は引き継がない")
        return []
    import duckdb

    con = duckdb.connect()
    try:
        con.execute("INSTALL ducklake; LOAD ducklake; INSTALL sqlite; LOAD sqlite; INSTALL httpfs; LOAD httpfs")
        escaped = working.replace("'", "''")
        # profiles.yml と同じく、この実行で書いたデータファイルは FDL_DATA_PATH から読む
        data_path = os.environ.get("FDL_DATA_PATH", "").replace("'", "''")
        options = f", DATA_PATH '{data_path}', OVERRIDE_DATA_PATH true" if data_path else ""
        con.execute("SET TimeZone = 'UTC'")
        con.execute(f"ATTACH 'ducklake:sqlite:{escaped}' AS previous (READ_ONLY{options})")
        exists = con.execute(
            "SELECT count(*) FROM information_schema.tables "
            "WHERE table_catalog = 'previous' AND table_schema = ? AND table_name = 'source_file'",
            [schema],
        ).fetchone()[0]
        if not exists:
            return []
        columns = ", ".join("strftime(retrieved_at, '%Y-%m-%dT%H:%M:%S+00:00') AS retrieved_at" if c == "retrieved_at" else c for c in SCHEMA.names)
        return con.execute(f"SELECT {columns} FROM previous.{schema}.source_file").fetch_arrow_table().to_pylist()
    finally:
        con.close()


def fetch(url: str, path: Path, previous: list[dict], page_url: str | None = None) -> dict:
    """url を path に取得し、source_file の 1 行を返す。"""
    last = max((r for r in previous if r["url"] == url), key=lambda r: r["retrieved_at"], default=None)
    for attempt in range(_NOT_FOUND_RETRIES):
        try:
            row = fetch_file(url, path, previous=last, user_agent=USER_AGENT, timeout=300)
            break
        except HTTPError as e:
            if e.code != 404 or attempt == _NOT_FOUND_RETRIES - 1:
                raise
            logger.warning(f"  404, retry in {2**attempt}s: {url}")
            time.sleep(2**attempt)
    return {**row, "page_url": page_url}


def write(path: Path, fetched: list[dict], previous: list[dict]) -> None:
    """前のバージョンの一覧に、今回の取得で初めて見た (url, sha256) の行を足して書く。"""
    rows = {(r["url"], r["sha256"]): r for r in previous}
    for r in fetched:
        rows.setdefault((r["url"], r["sha256"]), r)
    pq.write_table(pa.Table.from_pylist([{n: r.get(n) for n in SCHEMA.names} for r in rows.values()], schema=SCHEMA), path)
