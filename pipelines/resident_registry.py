"""住民基本台帳に基づく人口、人口動態及び世帯数の取得。

総務省の同調査は e-Stat のデータベースに登録が無く (getStatsList / getStatsData
は 0 件を返す)、統計表ファイルとしてのみ提供される。ファイルの所在は
getDataCatalog で辿れるので、年次ごとの Excel を落として NDJSON に整形する。

収録は市区町村別ファイル (1995年以降) と都道府県別ファイル (1994年以前) の
「人口、人口動態及び世帯数」表のみ。市区町村別ファイルには全国計と都道府県の行も
含まれるので、両方ある年は市区町村別だけを読む (突合したところ都道府県行の値は
完全に一致する)。年齢階級別の表は別構造なので扱わない。

データソース: 総務省 住民基本台帳に基づく人口、人口動態及び世帯数
https://www.soumu.go.jp/main_sosiki/jichi_gyousei/daityo/jinkou_jinkoudoutai-setaisuu.html
"""

import json
import logging
import re
import time
import urllib.parse
from http.client import IncompleteRead
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import pandas as pd

from pipelines import EstatStatus

logger = logging.getLogger("pipelines")

CATALOG_URL = "https://api.e-stat.go.jp/rest/3.0/app/json/getDataCatalog"
STATS_CODE = "00200241"
_UA = "dataset-e-stat"
_TIMEOUT = 300
_MAX_RETRIES = 4
_TRANSIENT_HTTP_CODES = {500, 502, 503, 504}
# getDataCatalog の 1 リクエストあたり上限。超えると status 102 で弾かれる。
PAGE_LIMIT = 100

ERA_BASE = {"明治": 1867, "大正": 1911, "昭和": 1925, "平成": 1988, "令和": 2018}
TITLE_RE = re.compile(r"^(明治|大正|昭和|平成|令和)(元|\d+)年(\d+)月(\d+)日")
# 見出しに紛れる年・年度の表記。列名としては意味を持たないので落とす。
YEAR_LABEL = re.compile(r"^(明治|大正|昭和|平成|令和)(元|\d+)年(度)?$|^\d{4}年$|^\d+年(度)?$")
UNIT_LABELS = {"人", "世帯", "％", "%"}
# 市区町村名の欄が空であることを示す記号。都道府県の行に入る。
BLANK_MARKS = {"-", "－", "‐", "―", "─"}
# 数値欄で「値が無い」ことを示す記号。*** は2024年の浜松市の再編前の区の行に入る。
NO_VALUE_MARKS = BLANK_MARKS | {"…", "*", "**", "***", "x", "X"}
CTRL_CHARS = re.compile(r"[\x00-\x1f\x7f]")
# ファイル名の末尾が住民区分と地域粒度を示す。s/n/g = 総計/日本人住民/外国人住民、
# t/s = 都道府県別/市区町村別。2012年以前は住民区分の接頭辞が無い。
FILE_RE = re.compile(r"([sng][ts]|[ts])jin$")
RESIDENT_KIND = {"s": "total", "n": "japanese", "g": "foreign"}

# 見出しラベル -> 出力列。年次で表記が揺れるので、揺れた分だけ両方を載せる。
COLUMN_MAP = {
    "団体コード": "lg_code",
    "都道府県名": "pref_name",
    "市区町村名": "municipality_name",
    "人口/男": "population_male",
    "人口/女": "population_female",
    "人口/計": "population_total",
    "世帯数": "households",
    "世帯数/計": "households",
    "住民票記載数/転入者数": "moved_in_total",
    "住民票記載数/転入者数（国内）": "moved_in_domestic",
    "住民票記載数/転入者数（国外）": "moved_in_overseas",
    "住民票記載数/転入者数（計）": "moved_in_total",
    "住民票記載数/出生者数": "births",
    "住民票記載数/その他": "other_added",
    "住民票記載数/その他（計）": "other_added",
    "住民票記載数/計（Ａ）": "total_added",
    "住民票消除数/転出者数": "moved_out_total",
    "住民票消除数/転出者数（国内）": "moved_out_domestic",
    "住民票消除数/転出者数（国外）": "moved_out_overseas",
    "住民票消除数/転出者数（計）": "moved_out_total",
    "住民票消除数/死亡者数": "deaths",
    "住民票消除数/その他": "other_removed",
    "住民票消除数/その他（計）": "other_removed",
    "住民票消除数/計（Ｂ）": "total_removed",
    "増減数（Ａ）-（Ｂ）": "net_change",
    "自然増加数": "natural_change",
    "自然増減数": "natural_change",
    "社会増加数": "social_change",
    "社会増減数": "social_change",
}

# 収録しない列。率は増減数と前年人口から出せるうえ年次によって空欄になる。
# 世帯数とその他の内訳は住民区分によって有無が変わるので、計だけを取る。
IGNORED_COLUMNS = {
    "",
    "人口/（修正人口）",
    "（修正世帯数）",
    "世帯数/日本人住民",
    "世帯数/日本人",
    "世帯数/複数国籍",
    "住民票記載数/その他（帰化等）",
    "住民票記載数/その他（国籍喪失）",
    "住民票記載数/その他（その他）",
    "住民票記載数/その他（法第30条の47）",
    "住民票消除数/その他（帰化等）",
    "住民票消除数/その他（国籍喪失）",
    "住民票消除数/その他（その他）",
    "増加率",
    "増減率",
    "自然増加率",
    "自然増減率",
    "社会増加率",
    "社会増減率",
}

MEASURES = [
    "population_male",
    "population_female",
    "population_total",
    "households",
    "moved_in_domestic",
    "moved_in_overseas",
    "moved_in_total",
    "births",
    "other_added",
    "total_added",
    "moved_out_domestic",
    "moved_out_overseas",
    "moved_out_total",
    "deaths",
    "other_removed",
    "total_removed",
    "net_change",
    "natural_change",
    "social_change",
]


def _fetch(url: str) -> tuple[bytes, str]:
    """再試行付きで URL を取得し、(本文, Content-Disposition) を返す。"""
    for attempt in range(_MAX_RETRIES):
        try:
            req = Request(url, headers={"User-Agent": _UA})
            with urlopen(req, timeout=_TIMEOUT) as resp:
                return resp.read(), resp.headers.get("Content-Disposition", "")
        # 応答の読み取り中に起きる失敗は URLError に包まれない。urllib が包むのは
        # 送信時の OSError だけで、getresponse() 以降はソケット層の
        # TimeoutError / ConnectionResetError と、本文が Content-Length に届かない
        # IncompleteRead がそのまま上がる。明示しないと再試行を素通りする。
        except (
            HTTPError,
            URLError,
            TimeoutError,
            ConnectionResetError,
            IncompleteRead,
        ) as e:
            transient = not isinstance(e, HTTPError) or e.code in _TRANSIENT_HTTP_CODES
            if not transient or attempt == _MAX_RETRIES - 1:
                raise
            wait = 2**attempt
            reason = getattr(e, "reason", None) or getattr(e, "code", None) or e
            logger.warning(f"  {reason}, retry in {wait}s ({attempt + 1}/{_MAX_RETRIES})")
            time.sleep(wait)
    raise RuntimeError("unreachable")


def _download(url: str) -> tuple[str, bytes]:
    """統計表ファイルを取得し、(ファイル名, 本文) を返す。

    e-Stat のファイルダウンロード URL は名前を持たず、Content-Disposition でしか
    区別できない。名前が住民区分と地域粒度を決めるので、取れなければ落とす。
    黙って読み飛ばすと、その年が欠けたままビルドが通ってしまう。
    """
    body, disposition = _fetch(url)
    m = re.search(r"filename\*=UTF-8''([^;]+)", disposition)
    if m:
        return urllib.parse.unquote(m.group(1)), body
    m = re.search(r'filename="?([^";]+)"?', disposition)
    if m:
        return m.group(1).strip(), body
    raise RuntimeError(
        f"Content-Disposition からファイル名を取れない: {disposition!r} ({url})"
    )


def _catalog(app_id: str) -> list[tuple[int, str]]:
    """getDataCatalog から調査結果の統計表ファイル URL を年次つきで集める。

    この統計は e-Stat のデータベースに登録が無く getStatsData で取れない。
    ファイル提供のカタログだけが所在を持つので、そこから辿る。
    """
    urls = []
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
        body, _ = _fetch(f"{CATALOG_URL}?{params}")
        root = json.loads(body)["GET_DATA_CATALOG"]
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
            if title["TABULATION_SUB_CATEGORY1"] != "調査の結果":
                continue
            resources = item["RESOURCES"]["RESOURCE"]
            if isinstance(resources, dict):
                resources = [resources]
            for res in resources:
                if res["FORMAT"] != "XLS":
                    continue
                urls.append((int(title["SURVEY_DATE"]), res["URL"]))

        next_key = catalog.get("RESULT_INF", {}).get("NEXT_KEY")
        if not next_key:
            break
        if int(next_key) <= start_position:
            raise RuntimeError(
                f"getDataCatalog: NEXT_KEY {next_key} が "
                f"startPosition {start_position} から進まない"
            )
        start_position = int(next_key)

    if not urls:
        raise RuntimeError(f"getDataCatalog に {STATS_CODE} の統計表ファイルが無い")
    return urls


def _text(value: object) -> str:
    """セル値を表示用に整える。制御文字と全角空白の混入を取り除く。"""
    if value is None or (isinstance(value, float) and pd.isna(value)):
        return ""
    s = CTRL_CHARS.sub("", str(value)).replace("　", " ")
    return re.sub(r"\s+", " ", s).strip()


def _label(value: object) -> str:
    """見出しラベル用。空白を詰め、丸括弧の全半角を全角に寄せる。"""
    return _text(value).replace(" ", "").replace("(", "（").replace(")", "）")


def _number(value: object) -> int | None:
    """数値セルを整数にする。値が無いことを示す記号は None、それ以外は落とす。

    読めない表記を黙って None にすると、負号が △ や ▲ に変わった年に負値だけが
    NULL になっても気づけない。値が無い記号だけを NULL とし、残りは落とす。
    """
    s = _label(value).replace(",", "")
    if not s or s in NO_VALUE_MARKS:
        return None
    try:
        return int(round(float(s)))
    except ValueError:
        raise RuntimeError(f"数値として読めないセル: {s!r}") from None


def _classify(stem: str) -> tuple[str, str]:
    """ファイル名から (住民区分, 地域粒度) を求める。"""
    m = FILE_RE.search(stem)
    if not m:
        raise RuntimeError(f"住民基本台帳の表として認識できないファイル名: {stem}")
    token = m.group(1)
    if len(token) == 2:
        return RESIDENT_KIND[token[0]], token[1]
    # 2012年以前は住民区分が分かれておらず、住民基本台帳は日本人住民のみを対象とする。
    return "japanese", token


def _column_index(df: pd.DataFrame, data_start: int) -> dict[str, int]:
    """多段の見出しを 1 本のラベルに畳み、出力列 -> 列位置の対応を返す。

    見出しは上段が結合セルでグループ名を、下段が内訳名を持つ。結合セルは
    pandas では左上にしか値が入らないので、最下段以外を横方向に前方補完して
    グループ名を配下の列へ流す。補完しないと「計」のような内訳名が人口の計か
    世帯数の計か区別できない。
    """
    header = df.iloc[1:data_start].map(_label)
    rows = [header.iloc[i].tolist() for i in range(len(header))]

    def forward_fill(row: list[str]) -> list[str]:
        filled, last = [], ""
        for v in row:
            if v:
                last = v
            filled.append(last)
        return filled

    rows = [forward_fill(r) for r in rows[:-1]] + [rows[-1]]

    index: dict[str, int] = {}
    unknown = []
    for col in range(df.shape[1]):
        parts: list[str] = []
        for row in rows:
            v = row[col]
            if not v or YEAR_LABEL.match(v) or v in UNIT_LABELS or v in parts:
                continue
            parts.append(v)
        label = "/".join(parts)
        field = COLUMN_MAP.get(label)
        if field is None:
            if label not in IGNORED_COLUMNS:
                unknown.append(label)
            continue
        index.setdefault(field, col)
    if unknown:
        raise RuntimeError(f"見出しに未知の列がある: {unknown}")
    for required in ("lg_code", "pref_name", "population_total"):
        if required not in index:
            raise RuntimeError(f"必須の列 {required} が見出しに無い")
    return index


def _parse(path: Path, resident_kind: str) -> list[dict]:
    engine = "openpyxl" if path.suffix == ".xlsx" else "xlrd"
    df = pd.read_excel(path, sheet_name=0, header=None, dtype=str, engine=engine)

    title = _label(df.iloc[0, 0])
    m = TITLE_RE.match(title)
    if not m:
        raise RuntimeError(f"{path.name}: 表題から調査期日を読めない: {title!r}")
    era, year_in_era, month, day = m.groups()
    year = ERA_BASE[era] + (1 if year_in_era == "元" else int(year_in_era))
    reference_date = f"{year:04d}-{int(month):02d}-{int(day):02d}"

    pref_column = [_label(v) for v in df[1].tolist()]
    if "合計" not in pref_column:
        raise RuntimeError(f"{path.name}: 全国計の行が見つからない")
    data_start = pref_column.index("合計")
    index = _column_index(df, data_start)

    records = []
    for i in range(data_start, len(df)):
        row = df.iloc[i]
        pref_name = _text(row[index["pref_name"]])
        if not pref_name:
            # 集計対象の行は必ず都道府県名を持つ。持たない行から下は注記。
            # ただし表の途中に空行が挟まると、ここで打ち切ると以降が黙って
            # 消える。残りに都道府県名を持つ行があれば注記ではないので落とす。
            rest = df.iloc[i + 1 :, index["pref_name"]].map(_text)
            if (rest != "").any():
                raise RuntimeError(
                    f"{path.name}: {i + 1} 行目で都道府県名が空だが、"
                    f"その下に {int((rest != '').sum())} 行のデータが残っている"
                )
            break

        code = _label(row[index["lg_code"]])
        if re.fullmatch(r"\d+(\.0)?", code):
            code = code.split(".")[0].zfill(6)
        if not re.fullmatch(r"\d{6}", code):
            # 東京都の島しょ集計行と、2009年の北方領土6村はコードを持たない。
            code = None

        municipality_name = (
            _text(row[index["municipality_name"]])
            if "municipality_name" in index
            else ""
        )
        if municipality_name in BLANK_MARKS:
            municipality_name = ""

        if pref_name == "合計":
            area_level, pref_name = "national", None
        else:
            area_level = "prefecture" if not municipality_name else "municipality"

        record = {
            "reference_date": reference_date,
            "year": year,
            "resident_kind": resident_kind,
            "area_level": area_level,
            "lg_code": code,
            "pref_name": pref_name,
            "municipality_name": municipality_name or None,
        }
        for field in MEASURES:
            col = index.get(field)
            record[field] = _number(row[col]) if col is not None else None
        records.append(record)
    return records


def build_resident_registry(dest_dir: str, app_id: str) -> None:
    """統計表ファイルを取得し、人口・世帯数・人口動態を NDJSON に整形する。"""
    dest = Path(dest_dir)
    files_dir = dest / "files"
    files_dir.mkdir(parents=True, exist_ok=True)

    downloaded: list[tuple[int, str, str, Path]] = []
    for year, url in _catalog(app_id):
        name, body = _download(url)
        # ダウンロード名は「【総計】市区町村別… 26ssjin.xlsx」の形。末尾の
        # 短い名前だけが住民区分と地域粒度を持つ。
        short = name.split()[-1]
        stem = Path(short).stem
        if not stem.endswith("jin"):
            continue  # 年齢階級別 (nen)・参考資料は扱わない
        resident_kind, scope = _classify(stem)
        path = files_dir / f"{year}_{short}"
        path.write_bytes(body)
        downloaded.append((year, resident_kind, scope, path))

    # (年, 住民区分) ごとに、市区町村別があればそれを、無ければ都道府県別を採る。
    # 市区町村別ファイルは全国計と都道府県の行も含み、値は都道府県別ファイルと一致する。
    chosen: dict[tuple[int, str], Path] = {}
    for year, resident_kind, scope, path in downloaded:
        key = (year, resident_kind)
        if key not in chosen or scope == "s":
            chosen[key] = path

    records: list[dict] = []
    for (year, resident_kind), path in sorted(chosen.items()):
        rows = _parse(path, resident_kind)
        if not rows:
            raise RuntimeError(f"{path.name}: データ行が 0 件")
        records.extend(rows)

    out = dest / "population.ndjson"
    with out.open("w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
    years = sorted({y for y, _ in chosen})
    logger.info(
        f"  population={len(records)} rows, "
        f"{len(chosen)} tables, {years[0]}-{years[-1]}"
    )
