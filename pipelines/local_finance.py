"""地方財政状況調査の取得 (getDataCatalog + 統計表 CSV)。

全国の都道府県・市区町村・一部事務組合が毎年度の決算を報告する調査で、
いわゆる「決算カード」の原資料にあたる。市区町村ごとの歳入歳出の規模と
財政力がそろう唯一の全数調査。

■ getStatsData を使わない理由

この統計は e-Stat のデータベースにも登録があるが (getStatsList は 265 表を
返す)、DB 側は 2018 年度調査までで更新が止まっている。2019 年度調査以降は
統計表ファイル (CSV) だけが提供されるので、getDataCatalog から辿って CSV を
読む。CSV は 1990 年度調査 (1989 年度決算) までさかのぼれる。

■ 取り込む調査表

調査表は年度あたり 130 表あるが、ここで取るのは 2 表だけ。

- 表 2「決算収支の状況」: 歳入総額・歳出総額・実質収支など 10 項目。
  市町村分・都道府県分の両方が 1990〜2025 年度調査でそろい、列の並びも変わらない。
- 表 0「表紙」: 基準財政収入額・基準財政需要額・標準財政規模・財政力指数。
  列に名前が付くのは市町村分の 2015 年度調査以降で、それ以前は「列001」…
  という無名の 90 列に変わり、同じ位置が別の項目を指す (2006 年度調査の
  列009 は財政力指数、2010 年度調査の列009 は臨時財政対策債発行可能額)。
  位置から項目を当てにいくと黙って別の値を読むので、名前付きの年だけを取る。
  都道府県分の表紙は 2002〜2007 年度調査しかなく、内容も普通会計の実質収支の
  符号コードで財政力を持たないため取らない。

■ 1 ファイルに 2 年度が入る

決算収支の状況は、1 つのファイルに行番号 1 (当年度) と行番号 2 (前年度) が
縦に並び、その境目に見出し行がもう一度入る。行番号 2 は前年のファイルと
同じ値なので、行番号 1 だけを取る。取らないと全項目が二重になる。

■ 団体コード

団体コードは全国地方公共団体コード (6 桁)。先頭ゼロが落ちて 5 桁で入る年が
あるので 6 桁に揃える。下 3 桁が 800 番台・900 番台の団体は一部事務組合と
広域連合で、市区町村ではない (実測: 団体区分 6・7 と完全に一致し、団体区分が
空欄になる 1990〜2000 年度調査でも同じ)。

データソース: 総務省 地方財政状況調査
https://www.e-stat.go.jp/stat-search/files?toukei=00200251
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
STATS_CODE = "00200251"
_UA = "dataset-e-stat"
_TIMEOUT = 300
# resident_registry と同じ理由。統計表ファイルの配信は、存在する URL に対しても
# 404 を返す窓を持つので、404 も一時障害として待つ。
_TRANSIENT_HTTP_CODES = {404, 500, 502, 503, 504}
_MAX_RETRIES = 8
_MAX_WAIT = 30
_MAX_NETWORK_RETRIES = 4
# getDataCatalog の 1 リクエストあたり上限。超えると status 102 で弾かれる。
PAGE_LIMIT = 100

SCOPE_BY_CATEGORY = {"市町村分": "municipality", "都道府県分": "prefecture"}
# 取らない区分。「全国」は集計値のみで団体別の行を持たない。ここに無い区分が
# 現れたら、文言が変わった合図として止める。
SKIPPED_CATEGORIES = {"全国"}
# 決算収支の状況は 1990 年度調査から両区分そろっている。1 つでも欠ける年度が
# あれば、収録がその年度だけ静かに片肺になる。
FIRST_SURVEY_YEAR = 1990
# 調査年 N の表は N+1 年 3 月末に出る。最新年が取れなくなったことに気づくための許容幅 (check_latest_year)。
LATEST_LAG_YEARS = 1

SETTLEMENT_TABLE_NO = "2"
COVER_TABLE_NO = "0"

# 表 2「決算収支の状況」。見出しの接頭番号 -> 出力列。
SETTLEMENT_COLUMNS = {
    "001": "revenue_total",
    "002": "expenditure_total",
    "003": "balance",
    "004": "carryover_resources",
    "005": "real_balance",
    "006": "single_year_balance",
    "007": "reserve_fund",
    "008": "early_redemption",
    "009": "reserve_fund_drawdown",
    "010": "real_single_year_balance",
}
# 見出しの文言。1999 年度調査だけ「積立金取り崩し額」と送り仮名が入る。
SETTLEMENT_LABELS = {
    "001": {"歳入総額"},
    "002": {"歳出総額"},
    "003": {"歳入歳出差引"},
    "004": {"翌年度に繰り越すべき財源"},
    "005": {"実質収支"},
    "006": {"単年度収支"},
    "007": {"積立金"},
    "008": {"繰上償還金"},
    "009": {"積立金取崩し額", "積立金取り崩し額"},
    "010": {"実質単年度収支"},
}

# 表 0「表紙」。列 001〜004 は「－」で値を持たない。
COVER_COLUMNS = {
    "005": "standard_revenue",
    "006": "standard_demand",
    "007": "standard_tax_revenue",
    "008": "standard_fiscal_scale",
    "009": "extraordinary_bond_limit",
    "010": "fiscal_capacity_index_x100",
}
COVER_LABELS = {
    "005": "基準財政収入額",
    "006": "基準財政需要額",
    "007": "標準税収入額等",
    "008": "標準財政規模",
    "009": "臨時財政対策債発行可能額",
    "010": "財政力指数",
}
# 財政力指数は小数第 2 位までを 100 倍した整数で入る (実測: 武蔵野市 157、
# 飛島村 199、夕張市 19 で、いずれも公表値の 100 倍)。100 で割るのは
# stg_local_finance_capacity で、丸めを SQL の側に見えるように置く。

HEADER_PREFIX = re.compile(r"^(\d{3}):\s*(.*)$")
ERA_BASE = {"明治": 1867, "大正": 1911, "昭和": 1925, "平成": 1988, "令和": 2018}
ROW_LABEL_RE = re.compile(r"^(明治|大正|昭和|平成|令和)(元|\d+)年度$")


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


def _catalog(app_id: str) -> list[tuple[int, str, str, str]]:
    """統計表ファイルの所在を (調査年度, 調査区分, 表番号, URL) で集める。"""
    found: list[tuple[int, str, str, str]] = []
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

        catalog = root["DATA_CATALOG_LIST_INF"]
        items = catalog["DATA_CATALOG_INF"]
        if isinstance(items, dict):
            items = [items]
        for item in items:
            title = item["DATASET"]["TITLE"]
            category = title["TABULATION_SUB_CATEGORY1"]
            if category in SKIPPED_CATEGORIES:
                # 「全国」は集計値のみで団体別の行を持たない。
                continue
            scope = SCOPE_BY_CATEGORY.get(category)
            if scope is None:
                # 区分の文言が変わると、その調査表が黙って丸ごと消える。
                raise RuntimeError(f"getDataCatalog: 未知の調査区分: {category!r}")
            resources = item["RESOURCES"]["RESOURCE"]
            if isinstance(resources, dict):
                resources = [resources]
            for res in resources:
                if res["FORMAT"] != "CSV":
                    continue
                # 表番号は年度によって "2" と "02" のどちらでも入る。
                no = str(res["TITLE"]["TABLE_NO"]).lstrip("0") or "0"
                if no in (SETTLEMENT_TABLE_NO, COVER_TABLE_NO):
                    found.append((int(title["SURVEY_DATE"]), scope, no, res["URL"]))

        next_key = catalog.get("RESULT_INF", {}).get("NEXT_KEY")
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

    # 決算収支の状況が年度 × 区分でそろっていることを確かめる。片方が欠けたまま
    # 進むと、その年度だけ市町村分か都道府県分が抜けた表ができあがる。
    settlement = {
        (year, scope)
        for year, scope, no, _ in found
        if no == SETTLEMENT_TABLE_NO
    }
    years = sorted({year for year, _ in settlement})
    check_latest_year(years[-1], LATEST_LAG_YEARS)
    expected = {
        (year, scope)
        for year in range(FIRST_SURVEY_YEAR, years[-1] + 1)
        for scope in SCOPE_BY_CATEGORY.values()
    }
    if missing := expected - settlement:
        raise RuntimeError(f"決算収支の状況が欠けている年度・区分: {sorted(missing)}")

    return sorted(found)


def _rows(body: bytes) -> list[list[str]]:
    """統計表 CSV (CP932) を行のリストにする。"""
    text = body.decode("cp932")
    return [[c.strip().replace("　", "") for c in row] for row in csv.reader(io.StringIO(text))]


def _header_index(header: list[str], labels: dict[str, set[str]]) -> dict[str, int]:
    """接頭番号つきの見出しから、番号 -> 列位置を求める。

    見出しの文言も照合する。並びが変わった年に位置だけで読むと、同じ列名の
    ままで中身が入れ替わっても気づけない。
    """
    index: dict[str, int] = {}
    for position, cell in enumerate(header):
        m = HEADER_PREFIX.match(cell)
        if not m:
            continue
        no, label = m.group(1), m.group(2)
        if no not in labels:
            continue
        # 単位や年度の注記が付く年がある (「基準財政収入額（千円）」)。
        label = re.sub(r"[（(].*", "", label).strip()
        if label not in labels[no]:
            raise RuntimeError(f"見出し {no} の文言が想定と違う: {label!r}")
        index[no] = position
    missing = set(labels) - set(index)
    if missing:
        raise RuntimeError(f"見出しに必要な列が無い: {sorted(missing)}")
    return index


def _number(value: str) -> int | None:
    s = value.replace(",", "")
    if not s or s in {"-", "－", "…", "*", "x", "X"}:
        return None
    try:
        return int(s)
    except ValueError:
        raise RuntimeError(f"数値として読めないセル: {value!r}") from None


def _check_row_label(row_label: str, fiscal_year: int) -> None:
    """行名称の元号年度が決算年度の列と一致することを確かめる。

    当年度と前年度の 2 ブロックが同じ決算年度の列を持つので、行番号だけで
    当年度を選んでいることの裏を取る。ずれたまま積むと前年度の値が当年度に
    化けるが、値そのものは正しく見えるので気づけない。
    """
    m = ROW_LABEL_RE.match(row_label)
    if not m:
        raise RuntimeError(f"行名称から年度を読めない: {row_label!r}")
    era, year_in_era = m.groups()
    year = ERA_BASE[era] + (1 if year_in_era == "元" else int(year_in_era))
    if year != fiscal_year:
        raise RuntimeError(
            f"行名称 {row_label!r} が決算年度 {fiscal_year} と合わない"
        )


def _parse(
    body: bytes, scope: str, labels: dict[str, set[str]], *, dated_rows: bool
) -> list[dict]:
    """統計表 CSV から当年度 (行番号 1) の行を取り出す。

    ファイルには当年度と前年度の 2 ブロックが縦に並び、境目に見出し行が
    もう一度入る。見出し行を捨て、行番号 1 のブロックだけを返す。
    """
    rows = _rows(body)
    header = rows[0]
    index = _header_index(header, labels)

    def col(name: str) -> int:
        if name not in header:
            raise RuntimeError(f"見出しに {name} が無い: {header[:10]}")
        return header.index(name)

    code_col = col("団体コード")
    name_col = col("団体名")
    category_col = col("団体区分")
    row_no_col = col("行番号")
    row_label_col = col("行名称")
    pref_col = col("県名")
    year_col = col("決算年度")

    records: list[dict] = []
    for row in rows[1:]:
        if not row or row[0] == header[0]:
            # ブロックの境目に入る 2 本目の見出し行。
            continue
        if row[row_no_col].lstrip("0") != "1":
            continue  # 行番号 2 は前年度の再掲

        fiscal_year = int(row[year_col])
        if dated_rows:
            _check_row_label(row[row_label_col], fiscal_year)
        raw_code = row[code_col]
        if raw_code.isdigit():
            lg_code: str | None = raw_code.zfill(6)
            entity_kind = (
                "prefecture"
                if scope == "prefecture"
                else ("association" if lg_code[2] in "89" else "municipality")
            )
        else:
            # 「合計(全国)」の行。ファイル内の全団体の単純合計。
            lg_code, entity_kind = None, "total"

        record = {
            "fiscal_year": fiscal_year,
            "survey_scope": scope,
            "entity_kind": entity_kind,
            "entity_category_code": row[category_col] or None,
            "lg_code": lg_code,
            "pref_name": row[pref_col] or None,
            "entity_name": row[name_col] or None,
        }
        for no, position in index.items():
            record[no] = _number(row[position])
        records.append(record)

    if not records:
        raise RuntimeError("当年度 (行番号 1) の行が 1 件も無い")
    return records


def _write(path: Path, records: list[dict]) -> None:
    with path.open("w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")


def build_local_finance(dest_dir: str, app_id: str) -> None:
    """統計表 CSV を取得し、決算収支と財政力を NDJSON に整形する。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)

    settlement: list[dict] = []
    capacity: list[dict] = []
    skipped_cover = 0

    for survey_year, scope, table_no, url in _catalog(app_id):
        body = _fetch(url)
        if table_no == SETTLEMENT_TABLE_NO:
            rows = _parse(body, scope, SETTLEMENT_LABELS, dated_rows=True)
            for row in rows:
                record = {k: v for k, v in row.items() if not k.isdigit()}
                for no, name in SETTLEMENT_COLUMNS.items():
                    record[name] = row[no]
                settlement.append(record)
            continue

        # 表紙は名前付きの見出しを持つ年だけを取る。無名の「列001」形式の年は
        # 同じ位置が別の項目を指すので、読まずに飛ばす。
        header = _rows(body)[0]
        if not any(HEADER_PREFIX.match(cell) for cell in header):
            skipped_cover += 1
            continue
        if scope != "municipality":
            # 都道府県分の表紙は財政力の列を持たない (普通会計の実質収支の符号)。
            skipped_cover += 1
            continue
        labels = {no: {label} for no, label in COVER_LABELS.items()}
        for row in _parse(body, scope, labels, dated_rows=False):
            if row["entity_kind"] == "total":
                # 「合計(全国)」の行。金額は全団体の合計だが、財政力指数の欄には
                # 指数ではない値が入る (2015年度調査で 85779)。列ごとに意味が
                # 変わる 1 行を混ぜないため落とす。
                continue
            if row["entity_kind"] != "municipality":
                # 一部事務組合と広域連合は地方交付税の算定対象ではなく、
                # 全項目が 0 で入る。0 でない年があれば読み方が変わった合図。
                values = [row[no] for no in COVER_COLUMNS]
                if any(v not in (0, None) for v in values):
                    raise RuntimeError(
                        f"{survey_year}年度調査 表紙: {row['entity_kind']} の行に"
                        f"値がある ({row['lg_code']} {row['entity_name']}): {values}"
                    )
                continue
            record = {
                k: v
                for k, v in row.items()
                if not k.isdigit() and k not in ("survey_scope", "entity_kind")
            }
            for no, name in COVER_COLUMNS.items():
                record[name] = row[no]
            capacity.append(record)

    if not settlement or not capacity:
        raise RuntimeError(
            f"取り込む行が足りない (settlement={len(settlement)}, "
            f"capacity={len(capacity)})"
        )

    _write(dest / "settlement.ndjson", settlement)
    _write(dest / "fiscal_capacity.ndjson", capacity)
    s_years = sorted({r["fiscal_year"] for r in settlement})
    c_years = sorted({r["fiscal_year"] for r in capacity})
    logger.info(
        f"  settlement={len(settlement)} rows, {s_years[0]}-{s_years[-1]}年度; "
        f"fiscal_capacity={len(capacity)} rows, {c_years[0]}-{c_years[-1]}年度 "
        f"(表紙 {skipped_cover} ファイルは列に名前が無く不使用)"
    )
