"""e-Stat「市区町村を探す」から、1970 年 4 月 1 日以降の市区町村コードと名前の履歴を取る。

load_local.py の fetcher (local_tables.yml の municipality_history)。CI の Sync では取らない。
廃置分合は年に数回しか無く、時点ごとの一覧を数百回取るので Sync の時間を食うため。

取るものは 2 つ。
- 廃置分合等の一覧 (1 行 = 1 つの改正で影響を受けた 1 つのコード)
- 市区町村コードの一覧を、1970-04-01 と廃置分合等の施行日ごとに取ったもの。
  一覧は「その日に有効だったコードと名前」なので、施行日ごとに並べると名前の有効期間が分かる

どちらも画面の「ダウンロード」(CSV) と同じ URL で取る。

https://www.e-stat.go.jp/municipalities/cities
"""

import csv
import io
import logging
import time
from datetime import date
from urllib.parse import urlencode

import pyarrow as pa
import pyarrow.parquet as pq

from shared.fetch import fetch

logger = logging.getLogger("pipelines")

USER_AGENT = "dataset-e-stat (+https://github.com/queria-io/dataset-e-stat)"
SITE = "https://www.e-stat.go.jp/municipalities/cities"
FIRST_DATE = date(1970, 4, 1)
# 市・区・町・村 (郡・支庁・振興局は含めない)。政令指定都市の市の行は「市」に入る
CITY_KINDS = (4, 5, 6, 7)
PREFECTURES = range(1, 48)

# (画面の項目名 item[], CSV の見出し, 列名)。CSV の列は item[] を渡した順に並ぶ
EVENT_FIELDS = (
    ("jiyuKind", "事由パターン", "pattern"),
    ("htCode", "標準地域コード", "area_code"),
    ("todoNm", "都道府県", "pref_name"),
    ("parentCityNm", "政令市･郡･支庁･振興局等", "parent_name"),
    ("selfCityNm", "市区町村", "name"),
    ("htCodeSDate", "廃置分合等施行年月日", "effective_date"),
    ("kaiseiJiyu", "改正事由", "reason"),
)
SNAPSHOT_FIELDS = (
    ("htCode", "標準地域コード", "area_code"),
    ("cityType", "都市種別", "city_type"),
    ("htCodeEDate", "標準地域コード廃止年月日", "abolished_date"),
    ("todoNm", "都道府県", "pref_name"),
    ("parentCityNm", "政令市･郡･支庁･振興局等", "parent_name"),
    ("parentCityKana", "政令市･郡･支庁･振興局等（ふりがな）", "parent_kana"),
    ("selfCityNm", "市区町村", "name"),
    ("selfCityKana", "市区町村（ふりがな）", "kana"),
)
# 廃置分合等の一覧の事由。画面の初期値 (すべて) と同じ
REASON_KINDS = (1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16)

EVENT_SCHEMA = pa.schema([(c, pa.string()) for _, _, c in EVENT_FIELDS])
SNAPSHOT_SCHEMA = pa.schema([("as_of", pa.string())] + [(c, pa.string()) for _, _, c in SNAPSHOT_FIELDS])


def _common(form_id: str, fields) -> list[tuple[str, str]]:
    return [
        ("form_id", form_id),
        *((f"pf[{p}]", str(p)) for p in PREFECTURES),
        *((f"city_kd[{k}]", str(k)) for k in CITY_KINDS),
        *(("item[]", item) for item, _, _ in fields),
        ("keyword_kd", "code"),
        # 並び順を渡さないと CSV ではなく画面が返る
        ("sort[]", "htCode-asc"),
        ("source", "setup"),
        ("file_format", "csv"),
        ("charset", "UTF-8"),
        ("bom", "0"),
        ("op", "download"),
    ]


def _download(path: str, params: list[tuple[str, str]], fields) -> list[dict]:
    body = fetch(f"{SITE}/{path}?{urlencode(params)}", user_agent=USER_AGENT)
    text = body.decode("utf-8")
    # 条件が受け付けられないと CSV ではなく画面の HTML が返る
    if not text.startswith('"'):
        raise RuntimeError(f"{path}: CSV ではない応答が返った (先頭: {text[:80]!r})")
    reader = csv.DictReader(io.StringIO(text))
    rows = list(reader)
    if missing := {h for _, h, _ in fields} - set(reader.fieldnames or ()):
        raise RuntimeError(f"{path}: 見出しが変わった。無い列: {sorted(missing)}")
    return [{c: (r[h] or None) for _, h, c in fields} for r in rows]


def events(until: date) -> list[dict]:
    params = [
        *_common("city_merger_form", EVENT_FIELDS),
        *((f"reason_kd[{k}]", str(k)) for k in REASON_KINDS),
        ("border_kd", "0"),
        ("year_from", str(FIRST_DATE.year)),
        ("month_from", str(FIRST_DATE.month)),
        ("day_from", str(FIRST_DATE.day)),
        ("year_to", str(until.year)),
        ("month_to", str(until.month)),
        ("day_to", str(until.day)),
    ]
    return _download("absorption-separation-of-municipalities", params, EVENT_FIELDS)


def snapshot(as_of: date) -> list[dict]:
    params = [
        *_common("city_areacode_form", SNAPSHOT_FIELDS),
        ("date_year", str(as_of.year)),
        ("date_month", str(as_of.month)),
        ("date_day", str(as_of.day)),
    ]
    rows = _download("areacode", params, SNAPSHOT_FIELDS)
    if not rows:
        raise RuntimeError(f"{as_of}: 市区町村コードの一覧が 0 行で返った")
    return [{"as_of": as_of.isoformat(), **r} for r in rows]


def latest_change_date(rows: list[dict]) -> str:
    return max(r["effective_date"] for r in rows)


def fetch_local(app_id: str, spec: dict, cache_path) -> None:
    """load_local.py の fetch。表ごとに cache_path(表) の Parquet を書く。

    local_tables.yml の catalog_modified_date には、廃置分合等の一覧の最新の施行日を書く。
    一覧の最新の施行日がこれと違うときは止まる。
    """
    del app_id  # e-Stat の API は使わない
    change_rows = events(date.today())
    latest = latest_change_date(change_rows)
    if latest != str(spec["catalog_modified_date"]):
        raise SystemExit(
            f"廃置分合等の最新の施行日 {latest} が local_tables.yml の "
            f"{spec['catalog_modified_date']} と違う。yml を直してから取り直す"
        )

    tables = {t["name"]: t for t in spec["tables"]}

    out = cache_path(tables["municipality_history_event"])
    if not out.exists():
        _write(out, pa.Table.from_pylist(change_rows, schema=EVENT_SCHEMA))

    out = cache_path(tables["municipality_history_snapshot"])
    if out.exists():
        logger.info("  municipality_history_snapshot: 取得済み")
        return
    dates = sorted({FIRST_DATE, *(date.fromisoformat(r["effective_date"]) for r in change_rows)})
    parts = []
    for i, as_of in enumerate(dates, 1):
        parts.append(pa.Table.from_pylist(snapshot(as_of), schema=SNAPSHOT_SCHEMA))
        logger.info(f"  {as_of} ({i}/{len(dates)}): {parts[-1].num_rows} 行")
        # 1 回に 1 つずつ、間を空けて取る
        time.sleep(1)
    _write(out, pa.concat_tables(parts))


def _write(out, table: pa.Table) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    # 書き終えてから名前を付ける。途中で止まった表を次の回に読まない
    tmp = out.with_suffix(".parquet.tmp")
    pq.write_table(table, tmp)
    tmp.rename(out)
    logger.info(f"  {out.name}: {table.num_rows} 行")
