"""エネルギー消費統計調査の都道府県別の表の取得 (getDataCatalog + 統計表 Excel)。

資源エネルギー庁のエネルギー消費統計調査の参考表から、都道府県別のエネルギー消費量を
業種別 (参考1) とエネルギー種別 (参考2) の 2 通りに取る。2009 年度から毎年度。

■ 取り込み方

年に 1 度しか出ず、過去の年度も直らないので、CI の Sync では取らない。load_local.py の
energy_consumption グループとして手元で 1 回取り、公開する。更新は
scripts/check_local_updates.py が getDataCatalog の更新日で見張る。

■ getStatsData を使わない理由

e-Stat のデータベースにある表は 2016 年度の 9 表だけで、都道府県別の表は無い。
提供は統計表ファイル (Excel) で、getDataCatalog から辿る。

■ 取り込む表

年度ごとに「エネルギー消費統計調査結果（石油等消費動態統計を含まない）」の
参考表 4-1 (都道府県別・業種別エネルギー消費量表) と 4-2 (都道府県別・エネルギー種別
エネルギー消費量表)。「石油等消費動態統計を含む試算表」の側に都道府県別の表は無い。

どちらのファイルも固有単位表 (A、原油換算 kl や t・m3) と熱量単位表 (B、TJ) の 2 シート
を持つ。単位がそろって足し算のできる熱量単位表だけを読む。

■ 表の形

行は全国計・地域ブロックの計・47 都道府県。地域ブロックの計は都道府県を足せば出るので
読まない。列の位置は年度で変わる (2018 年度までと 2023 年度のファイルは、1 シートの中で
ページが横に並び、間に行見出しの列が挟まる)。単位の行が TJ の列だけを値の列とする。

列見出しは年度で書き方が違う。
- 業種別: 産業分類の記号 (A~S・9・F~S など) の行と名前の行。記号で業種を決める
- エネルギー種別: 「燃料 / 非石油系燃料 / 石炭」を 3 段に分けて書く年度と、1 つのセルに
  「燃料_非石油系燃料_石炭」と書く年度がある。いちばん下の名前で種別を決める
  (37 の名前はどれも重ならない)

■ 値

熱量 (TJ) の実数。空欄と「-」は無い (あれば止める)。

データソース: 資源エネルギー庁 エネルギー消費統計調査
https://www.e-stat.go.jp/stat-search/files?toukei=00551005
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
from pipelines.school import _fetch

logger = logging.getLogger("pipelines")

CATALOG_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getDataCatalog"
STATS_CODE = "00551005"
PAGE_LIMIT = 100

# 都道府県別の参考表が出る最初の年度
FIRST_FISCAL_YEAR = 2009
# N 年度の結果は N+2 年の 3 月末に出る (令和6年度は 2026-03-31)。
LATEST_LAG_YEARS = 2

# 表の種類 → 統計表ファイルの表題に含まれる語
TABLE_TITLES = {
    "industry": "都道府県別・業種別エネルギー消費量",
    "energy_type": "都道府県別・エネルギー種別エネルギー消費量",
}
DATASET_TITLE = "石油等消費動態統計を含まない"

PREFECTURES = (
    "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県", "茨城県",
    "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県", "新潟県", "富山県",
    "石川県", "福井県", "山梨県", "長野県", "岐阜県", "静岡県", "愛知県", "三重県",
    "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県", "鳥取県", "島根県",
    "岡山県", "広島県", "山口県", "徳島県", "香川県", "愛媛県", "高知県", "福岡県",
    "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県",
)  # fmt: skip
NATIONWIDE_LABEL = "全国計"

# 産業分類の記号 → (名前, 上位の記号)。名前は原典の表記 (NFKC で畳んだもの、2009〜2024 年度で同じ)。
# 上位を足し合わせると、上位の記号の値になる (A~D = A+B+C+D、E = 9〜32 など)。
INDUSTRIES = {
    "A~S": ("業種計", None),
    "A~D": ("非製造業計", "A~S"),
    "A": ("農業、林業", "A~D"),
    "B": ("漁業", "A~D"),
    "C": ("鉱業、採石業、砂利採取業", "A~D"),
    "D": ("建設業", "A~D"),
    "E": ("製造業", "A~S"),
    "9": ("食料品製造業", "E"),
    "10": ("飲料、たばこ、飼料製造業", "E"),
    "11": ("繊維工業", "E"),
    "12": ("木材、木製品製造業(家具を除く)", "E"),
    "13": ("家具、装備品製造業", "E"),
    "14": ("パルプ、紙、紙加工品製造業", "E"),
    "15": ("印刷、同関連業", "E"),
    "16": ("化学工業", "E"),
    "17": ("石油製品、石炭製品製造業", "E"),
    "18": ("プラスチック製品製造業(別掲を除く)", "E"),
    "19": ("ゴム製品製造業", "E"),
    "20": ("なめし革、同製品、毛皮製造業", "E"),
    "21": ("窯業、土石製品製造業", "E"),
    "22": ("鉄鋼業", "E"),
    "23": ("非鉄金属製造業", "E"),
    "24": ("金属製品製造業", "E"),
    "25": ("はん用機械器具製造業", "E"),
    "26": ("生産用機械器具製造業", "E"),
    "27": ("業務用機械器具製造業", "E"),
    "28": ("電子部品、デバイス、電子回路製造業", "E"),
    "29": ("電気機械器具製造業", "E"),
    "30": ("情報通信機械器具製造業", "E"),
    "31": ("輸送用機械器具製造業", "E"),
    "32": ("その他の製造業", "E"),
    "F~S": ("業務部門計", "A~S"),
    "F": ("電気、ガス、熱供給、水道業", "F~S"),
    "G": ("情報通信業", "F~S"),
    "H": ("運輸業、郵便業", "F~S"),
    "I": ("卸売、小売業", "F~S"),
    "J": ("金融、保険業", "F~S"),
    "K": ("不動産業、物品賃貸業", "F~S"),
    "L": ("学術研究、専門・技術サービス業", "F~S"),
    "M": ("宿泊業、飲食サービス業", "F~S"),
    "N": ("生活関連サービス業、娯楽業", "F~S"),
    "O": ("教育、学習支援業", "F~S"),
    "P": ("医療、福祉", "F~S"),
    "Q": ("複合サービス業", "F~S"),
    "R": ("サービス業(他に分類されないもの)", "F~S"),
    "S": ("公務(他に分類されるものを除く)", "F~S"),
}

# エネルギー種別 → 上位の種別。並びは原典の列の順。
ENERGY_TYPES = {
    "合計": None,
    "燃料": "合計",
    "非石油系燃料": "燃料",
    "石炭": "非石油系燃料",
    "石炭コークス": "非石油系燃料",
    "タール": "非石油系燃料",
    "コークス炉ガス": "非石油系燃料",
    "高炉ガス": "非石油系燃料",
    "転炉ガス": "非石油系燃料",
    "電気炉ガス": "非石油系燃料",
    "天然ガス": "非石油系燃料",
    "液化天然ガス": "非石油系燃料",
    "都市ガス": "非石油系燃料",
    "廃タイヤ": "非石油系燃料",
    "廃プラスチック": "非石油系燃料",
    "その他の再生可能・未活用エネルギー": "非石油系燃料",
    "石油系燃料": "燃料",
    "原油": "石油系燃料",
    "ガソリン": "石油系燃料",
    "ジェット燃料": "石油系燃料",
    "ナフサ": "石油系燃料",
    "改質生成油": "石油系燃料",
    "灯油": "石油系燃料",
    "軽油": "石油系燃料",
    "A重油": "石油系燃料",
    "B・C重油": "石油系燃料",
    "炭化水素油": "石油系燃料",
    "液化石油ガス": "石油系燃料",
    "石油系炭化水素ガス": "石油系燃料",
    "オイルコークス": "石油系燃料",
    "他石油製品": "石油系燃料",
    "電力": "合計",
    "買電": "電力",
    "自家発電": "電力",
    "熱": "合計",
    "蒸気": "熱",
    "温水・冷水": "熱",
}

HEAT_SHEET_MARK = "熱量単位表"
UNIT = "TJ"
NUMBER_RE = re.compile(r"^-?\d+(\.\d+)?([eE]-?\d+)?$")

INDUSTRY_SCHEMA = pa.schema(
    [
        ("fiscal_year", pa.int32()),
        ("prefecture_name", pa.string()),
        ("industry_code", pa.string()),
        ("industry_name", pa.string()),
        ("parent_industry_code", pa.string()),
        ("value", pa.float64()),
    ]
)
ENERGY_TYPE_SCHEMA = pa.schema(
    [
        ("fiscal_year", pa.int32()),
        ("prefecture_name", pa.string()),
        ("energy_type", pa.string()),
        ("parent_energy_type", pa.string()),
        ("value", pa.float64()),
    ]
)


def _norm(cell) -> str:
    """全角英数・全角空白を畳み、空白と改行を除く。"""
    if cell is None or (isinstance(cell, float) and pd.isna(cell)):
        return ""
    return re.sub(r"\s", "", unicodedata.normalize("NFKC", str(cell)))


def catalog_resources(app_id: str) -> list[dict]:
    """取り込む 2 表の統計表ファイルを、年度ごとに集める。

    戻り値の各要素は fiscal_year・kind (industry / energy_type)・url・last_modified_date。
    統計全体の最終更新日を出すため、ほかの表のファイルも last_modified_date だけ残す
    (kind が None)。
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
            dataset = item["DATASET"]["TITLE"]
            # SURVEY_DATE は「202404-202503」のような年度の範囲
            fiscal_year = int(str(dataset["SURVEY_DATE"])[:4])
            item_resources = item["RESOURCES"]["RESOURCE"]
            for res in [item_resources] if isinstance(item_resources, dict) else item_resources:
                title = res["TITLE"]
                name = f"{title.get('NAME', '')} {title.get('TABLE_NAME', '')}"
                kind = next((k for k, word in TABLE_TITLES.items() if word in name), None)
                if DATASET_TITLE not in dataset["NAME"] or res["FORMAT"] != "XLS":
                    kind = None
                resources.append(
                    {
                        "fiscal_year": fiscal_year,
                        "kind": kind,
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


def catalog(resources: list[dict]) -> list[tuple[int, str, str]]:
    """取り込む表の所在を (年度, 表の種類, URL) で集める。年度の連続と 2 表のそろいを押さえる。"""
    found: dict[tuple[int, str], str] = {}
    for res in resources:
        if res["kind"] is None or res["fiscal_year"] < FIRST_FISCAL_YEAR:
            continue
        key = (res["fiscal_year"], res["kind"])
        if key in found:
            raise RuntimeError(f"{res['fiscal_year']}年度の {res['kind']} に表が 2 つある")
        found[key] = res["url"]

    years = sorted({year for year, _ in found})
    if not years:
        raise RuntimeError("都道府県別の表が見つからない")
    check_latest_year(years[-1], LATEST_LAG_YEARS)
    if missing := [
        f"{year} {kind}"
        for year in range(FIRST_FISCAL_YEAR, years[-1] + 1)
        for kind in TABLE_TITLES
        if (year, kind) not in found
    ]:
        raise RuntimeError(f"表が欠けている: {missing}")
    return sorted((year, kind, url) for (year, kind), url in found.items())


def _heat_sheet(body: bytes, where: str) -> pd.DataFrame:
    """熱量単位表 (TJ) のシートを返す。"""
    engine = "openpyxl" if body[:2] == b"PK" else "xlrd"
    sheets = pd.read_excel(io.BytesIO(body), engine=engine, header=None, dtype=str, sheet_name=None)
    found = [
        df
        for df in sheets.values()
        if (df.map(_norm).apply(lambda col: col.str.contains(HEAT_SHEET_MARK))).any().any()
    ]
    if len(found) != 1:
        raise RuntimeError(f"{where}: 熱量単位表のシートが {len(found)} 枚")
    return found[0].map(_norm)


def _unit_row(cells: pd.DataFrame, where: str) -> tuple[int, list[int]]:
    """(単位の行, 値の列) を返す。TJ のセルが最も多い行を単位の行とする。"""
    counts = (cells == UNIT).sum(axis=1)
    row = int(counts.idxmax())
    if counts[row] == 0:
        raise RuntimeError(f"{where}: 単位 {UNIT} の行が無い")
    return row, [c for c in range(cells.shape[1]) if cells.iat[row, c] == UNIT]


def _rows(cells: pd.DataFrame, start: int, where: str) -> dict[str, int]:
    """都道府県名 (全国は「全国計」) → 行番号。行見出しは先頭の数列のどこかにある。"""
    labels = set(PREFECTURES) | {NATIONWIDE_LABEL}
    rows: dict[str, int] = {}
    for r in range(start, len(cells)):
        label = next(
            (cells.iat[r, c] for c in range(min(5, cells.shape[1])) if cells.iat[r, c] in labels), None
        )
        if label is None:
            continue
        if label in rows:
            raise RuntimeError(f"{where}: {label} の行が 2 つある")
        rows[label] = r
    if missing := labels - rows.keys():
        raise RuntimeError(f"{where}: 行が無い: {sorted(missing)}")
    return rows


def _value(cell: str, where: str) -> float:
    s = cell.replace(",", "")
    if not NUMBER_RE.match(s):
        raise RuntimeError(f"{where}: 数値として読めないセル {cell!r}")
    return float(s)


def _records(
    cells: pd.DataFrame, columns: dict[int, str], unit_row: int, fiscal_year: int, where: str
) -> list[dict]:
    rows = _rows(cells, unit_row + 1, where)
    return [
        {"fiscal_year": fiscal_year, "prefecture_name": label, "key": key,
         "value": _value(cells.iat[r, c], f"{where} {label} {key}")}
        for label, r in rows.items()
        for c, key in columns.items()
    ]  # fmt: skip


def parse_industry(body: bytes, fiscal_year: int) -> list[dict]:
    """参考1 都道府県別・業種別エネルギー消費量 (熱量単位表) を 1 セル 1 行にする。"""
    where = f"{fiscal_year}年度 業種別"
    cells = _heat_sheet(body, where)
    unit_row, value_cols = _unit_row(cells, where)
    # 記号の行は単位の行の 2 つ上、名前の行は 1 つ上 (記号 → 名前 → 単位)
    columns = {c: cells.iat[unit_row - 2, c] for c in value_cols}
    if sorted(columns.values()) != sorted(INDUSTRIES):
        raise RuntimeError(f"{where}: 業種の記号が想定と違う: {sorted(columns.values())}")
    if renamed := {
        code: cells.iat[unit_row - 1, c]
        for c, code in columns.items()
        if cells.iat[unit_row - 1, c] != INDUSTRIES[code][0]
    }:
        raise RuntimeError(f"{where}: 業種の名前が想定と違う: {renamed}")
    return [
        {
            "fiscal_year": r["fiscal_year"],
            "prefecture_name": r["prefecture_name"],
            "industry_code": r["key"],
            "industry_name": INDUSTRIES[r["key"]][0],
            "parent_industry_code": INDUSTRIES[r["key"]][1],
            "value": r["value"],
        }
        for r in _records(cells, columns, unit_row, fiscal_year, where)
    ]


def parse_energy_type(body: bytes, fiscal_year: int) -> list[dict]:
    """参考2 都道府県別・エネルギー種別エネルギー消費量 (熱量単位表) を 1 セル 1 行にする。"""
    where = f"{fiscal_year}年度 エネルギー種別"
    cells = _heat_sheet(body, where)
    unit_row, value_cols = _unit_row(cells, where)
    columns = {}
    for c in value_cols:
        # 見出しは単位の行より上の数行。いちばん下の空でないセルの、「_」区切りの最後が種別
        header = next(
            (cells.iat[r, c] for r in range(unit_row - 1, max(unit_row - 6, -1), -1) if cells.iat[r, c]), ""
        )
        columns[c] = header.split("_")[-1]
    if sorted(columns.values()) != sorted(ENERGY_TYPES):
        raise RuntimeError(f"{where}: エネルギー種別が想定と違う: {sorted(columns.values())}")
    return [
        {
            "fiscal_year": r["fiscal_year"],
            "prefecture_name": r["prefecture_name"],
            "energy_type": r["key"],
            "parent_energy_type": ENERGY_TYPES[r["key"]],
            "value": r["value"],
        }
        for r in _records(cells, columns, unit_row, fiscal_year, where)
    ]


# load_local.py の表の名前 → (表の種類, パーサー, スキーマ)
TABLES = {
    "energy_consumption_industry": ("industry", parse_industry, INDUSTRY_SCHEMA),
    "energy_consumption_energy_type": ("energy_type", parse_energy_type, ENERGY_TYPE_SCHEMA),
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
        for fiscal_year, entry_kind, url in entries:
            if entry_kind != kind:
                continue
            path = files / f"{fiscal_year}_{kind}.xls"
            if not path.exists():
                # 書き終えてから名前を付ける。途中で止まった壊れたファイルを次の回に読まない
                tmp_file = path.with_suffix(".xls.tmp")
                tmp_file.write_bytes(_fetch(url))
                tmp_file.rename(path)
            parsed = parse(path.read_bytes(), fiscal_year)
            logger.info(f"  {name} {fiscal_year}年度: {len(parsed)} 行")
            parts.append(pa.Table.from_pylist(parsed, schema=schema))
        table_ = pa.concat_tables(parts)
        tmp = out.with_suffix(".parquet.tmp")
        pq.write_table(table_, tmp)
        tmp.rename(out)
        logger.info(f"  {name}: {table_.num_rows} 行")
