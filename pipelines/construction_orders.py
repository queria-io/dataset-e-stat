"""建設工事受注動態統計調査の取得 (getDataCatalog + 統計表 Excel)。

建設業許可業者から標本を抜き、毎月の受注高を調べて許可業者全体へ復元する調査。
ここで取るのは「公共機関からの受注工事（1件500万円以上の工事）」の
「発注機関別・施工都道府県別請負契約額」で、月ごとに 1 ファイル出る。
施工都道府県 (全国計と 47 都道府県) ごとに、国の機関 (国・独立行政法人・
政府関連企業等) と地方の機関 (都道府県・市区町村・地方公営企業・その他) の
請負契約額 (百万円) が並ぶ。

■ getStatsData を使わない理由

e-Stat のデータベースにあるのは大手 50 社調査だけで、許可業者全体への推計値は
統計表ファイルでしか出ていない。

■ 取り込む月

2021 年 4 月から。この月から推計方法が変わり、施工統計調査の未回答業者の欠測を
補完して復元するようになった。2013 年 4 月〜2021 年 3 月は未回答業者を実績なしと
して扱う方法で、水準がつながらない (2020 年 1 月〜2021 年 3 月は新しい方法で
参考値として再集計されているが、月別のファイルには入っていない)。

月を足した年度計は、年度次の同じ表 (発注者別・施工都道府県別請負契約額表) と
全国・都道府県・発注機関のすべてで一致する (2025 年度で確認)。

■ 表の形

1 シート目の上半分が施工都道府県別、下半分が施工地域 (9 地方) 別。上半分だけを読む。
列は 合計・前年同月比・国の機関・国・独立行政法人・政府関連企業等・地方の機関・
都道府県・市区町村・地方公営企業・その他 の順。前年同月比は取らない。
行見出しは「T.全国計」「1.北海道」「13.東京」の形。該当の無いセルは空欄。
変更契約で減額された分が多い月は値が負になる。

データソース: 国土交通省 建設工事受注動態統計調査
https://www.e-stat.go.jp/stat-search/files?toukei=00600130
"""

import io
import json
import logging
import re
import unicodedata
import urllib.parse
from pathlib import Path

import pandas as pd

from pipelines import EstatStatus
from pipelines.school import NATIONWIDE_CODE, PAGE_LIMIT, PREFECTURES, _fetch

logger = logging.getLogger("pipelines")

CATALOG_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getDataCatalog"
STATS_CODE = "00600130"

FIRST_MONTH = (2021, 4)
# 調査月の結果は翌々月の上旬に出る。それより遅れていたら表題か配信が変わっている。
MAX_LAG_MONTHS = 4

DATASET_RE = re.compile(r"_公共機関からの受注_月次_(\d{4})年(\d{1,2})月$")
RESOURCE_NAME = "発注者別・施工都道府県別請負契約額表"
FILE_FORMATS = {"XLS", "XLS_REP"}

BLOCK_TITLE = "発注機関別・施工都道府県別請負契約額"
PERIOD_RE = re.compile(r"令和(\d+)年(\d{1,2})月分")
ROW_RE = re.compile(r"^(T|\d{1,2})\.(.+)$")
# 見出しの並びと出力の列名。前年同月比の列は飛ばす。
COLUMNS = (
    ("合計", "total"),
    ("前年同月比", None),
    ("国の機関", "national_total"),
    ("国", "national_government"),
    ("独立行政法人", "independent_agency"),
    ("政府関連企業等", "government_affiliated"),
    ("地方の機関", "local_total"),
    ("都道府県", "prefectural_government"),
    ("市区町村", "municipal_government"),
    ("地方公営企業", "local_public_enterprise"),
    ("その他", "other"),
)
AMOUNT_COLUMNS = tuple(key for _, key in COLUMNS if key)


def _norm(cell) -> str:
    """全角英数・全角空白を畳み、空白と改行を除く。"""
    if cell is None or (isinstance(cell, float) and pd.isna(cell)):
        return ""
    s = unicodedata.normalize("NFKC", str(cell))
    return re.sub(r"\s", "", s)


def _months_between(start: tuple[int, int], end: tuple[int, int]) -> list[tuple[int, int]]:
    months = []
    year, month = start
    while (year, month) <= end:
        months.append((year, month))
        year, month = (year + 1, 1) if month == 12 else (year, month + 1)
    return months


def catalog(app_id: str, today: pd.Timestamp | None = None) -> list[tuple[int, int, str]]:
    """発注機関別・施工都道府県別の表の所在を (年, 月, URL) で集める。"""
    found: dict[tuple[int, int], str] = {}
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
            m = DATASET_RE.search(item["DATASET"]["TITLE"]["NAME"])
            if not m:
                continue
            ym = (int(m.group(1)), int(m.group(2)))
            if ym < FIRST_MONTH:
                continue
            resources = item["RESOURCES"]["RESOURCE"]
            if isinstance(resources, dict):
                resources = [resources]
            for res in resources:
                if _norm(res["TITLE"].get("NAME")) != RESOURCE_NAME:
                    continue
                if res["FORMAT"] not in FILE_FORMATS:
                    continue
                if ym in found:
                    raise RuntimeError(f"{ym[0]}年{ym[1]}月 {RESOURCE_NAME} が 2 つある")
                found[ym] = res["URL"]

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
        raise RuntimeError(f"getDataCatalog に {STATS_CODE} の {RESOURCE_NAME} が無い")

    # 表題が変わって 1 か月だけ落ちても、ほかの月の行は残るので行数でも値でも
    # 気づけない。月の連続と、最新月が遅れすぎていないことをここで押さえる。
    latest = max(found)
    today = today or pd.Timestamp.today()
    lag = (today.year - latest[0]) * 12 + today.month - latest[1]
    if lag > MAX_LAG_MONTHS:
        raise RuntimeError(f"最新の {RESOURCE_NAME} が {latest[0]}年{latest[1]}月で {lag} か月遅れている")
    if missing := [ym for ym in _months_between(FIRST_MONTH, latest) if ym not in found]:
        raise RuntimeError(f"{RESOURCE_NAME} が欠けている: {missing}")
    return [(y, m, found[(y, m)]) for y, m in sorted(found)]


def _area(number: str, label: str, where: str) -> tuple[str, str | None, str]:
    """行見出しから (地域コード, 都道府県コード, 名前) を返す。"""
    if number == "T":
        if label != "全国計":
            raise RuntimeError(f"{where}: 全国計の行が {label!r}")
        return NATIONWIDE_CODE, None, "全国"
    index = int(number)
    if not 1 <= index <= len(PREFECTURES) or PREFECTURES[index - 1] != label:
        raise RuntimeError(f"{where}: 都道府県の行が {number}.{label}")
    name = PREFECTURES[index - 1]
    suffix = "" if name == "北海道" else "都" if name == "東京" else "府" if name in ("京都", "大阪") else "県"
    return f"{index:02d}000", f"{index:02d}", name + suffix


def _amount(cell, where: str) -> float:
    if cell is None or (isinstance(cell, float) and pd.isna(cell)) or _norm(cell) == "":
        return 0.0
    if isinstance(cell, (int, float)):
        return float(cell)
    raise RuntimeError(f"{where}: 数値として読めないセル {cell!r}")


def parse(body: bytes, year: int, month: int) -> list[dict]:
    """1 か月分のファイルを 全国計 + 47 都道府県 の行にする。"""
    where = f"{year}年{month}月"
    sheet = pd.read_excel(io.BytesIO(body), sheet_name=0, header=None, dtype=object)
    rows = sheet.values.tolist()
    labels = [[_norm(c) for c in row] for row in rows]

    title_row = next((i for i, r in enumerate(labels) if any(BLOCK_TITLE in c for c in r)), None)
    if title_row is None:
        raise RuntimeError(f"{where}: {BLOCK_TITLE} の表が無い")
    period = PERIOD_RE.search("".join(labels[title_row]))
    if not period or (2018 + int(period.group(1)), int(period.group(2))) != (year, month):
        raise RuntimeError(f"{where}: 表の調査月が {''.join(labels[title_row])!r}")

    # 見出しは表題の下の 2 行。列の位置を見出しの文字で決める。
    header = [" ".join(filter(None, col)) for col in zip(*labels[title_row + 1 : title_row + 4])]
    positions: list[tuple[int, str]] = []
    cursor = 1
    for name, key in COLUMNS:
        c = next((j for j in range(cursor, len(header)) if header[j].split(" ")[-1] == name), None)
        if c is None:
            raise RuntimeError(f"{where}: 見出し {name} が無い: {header}")
        if key:
            positions.append((c, key))
        cursor = c + 1

    records: dict[str, dict] = {}
    for i in range(title_row + 4, len(rows)):
        m = ROW_RE.match(labels[i][0])
        if not m:
            if records and labels[i][0] == "":
                # 表の下の注記で上半分が終わる。
                break
            continue
        area, prefecture_code, area_name = _area(m.group(1), m.group(2), where)
        if area in records:
            raise RuntimeError(f"{where}: {area_name} の行が 2 つある")
        record = {
            "year": year,
            "month": month,
            "area": area,
            "prefecture_code": prefecture_code,
            "area_name": area_name,
        }
        for c, key in positions:
            record[key] = _amount(rows[i][c], f"{where} {area_name} {key}")
        records[area] = record

    if len(records) != 1 + len(PREFECTURES):
        raise RuntimeError(f"{where}: 地域が {len(records)} 行 (48 行のはず)")
    return list(records.values())


def build_construction_orders(dest_dir: str, app_id: str) -> None:
    """公共工事の発注機関別・施工都道府県別の表を取得し、NDJSON に整形する。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)

    records: list[dict] = []
    for year, month, url in catalog(app_id):
        records += parse(_fetch(url), year, month)

    with (dest / "public_orders_prefecture_monthly.ndjson").open("w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
    first, last = records[0], records[-1]
    logger.info(
        f"  public_orders_prefecture_monthly={len(records)} rows, "
        f"{first['year']}-{first['month']:02d}〜{last['year']}-{last['month']:02d}"
    )
