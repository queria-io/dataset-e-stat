"""作物統計調査 野菜生産出荷統計の都道府県別の表の取得 (getStatsList + getStatsData)。

農林水産省が毎年まとめる野菜の作付面積・10a当たり収量・収穫量・出荷量を、
年産 × 品目 × 作型 × 地域 の 1 行にする。地域は全国と 47 都道府県。

■ 取る表

政府統計コード 00500215 (作物統計調査) のうち、統計名が
「作物統計調査 作況調査（野菜） 確報 平成26年産野菜生産出荷統計」の形で、表題に
「都道府県別の作付面積」を含む表。平成16年産〜令和6年産で 1,425 表。
同じ統計の「都道府県別・品目別の作付面積…」「都道府県順位（上位５位）」
「市町村別」「野菜指定産地」「用途別出荷量」はこの条件で外れる。
表題の番号 (@no) は年で 3・4・2-1-1 と揺れるので条件に使わない。

■ 表の形は年代で 3 通り

- 平成16年産・令和元年産: 全品目で 1 表。品目 (cat02) に「春キャベツ」
  「夏秋レタスのうち、サラダ菜」のように作型とうち内訳が入る。平成16年産は time に
  2003 年も持ち、平成15年産の都道府県別はここにしか無い (平成15年産の表は上位5位だけ)
- 平成17〜30年産・令和2年産: 1 品目 1 作型 1 表。品目と作型は表題の末尾
  「… キャベツ 夏秋」にしか無い。2005〜2009 年は「春キャベツ」、以降は「春」
- 令和3年産以降: 1 品目 1 表。地域が area ではなく cat01 に入り、作型は項目
  (cat02) の「春_収穫量」のような接頭辞で分かれる

■ 地域はコードでなく名前で当てる

地域コードは年代で 08000 → 08000 → 1020 と変わり、N0001 は平成16年産では
関東農政局、平成26年産では全国を指す。コードでつなぐと別の地域が混ざるので、
名前「茨城県」「（都道府県）_茨城県」「（都道府県）_茨城」から都道府県を決め、
標準地域コード (08000) を振り直す。全国農業地域・農政局の行は取らない。

■ 値の記号

「…」(事実不詳・調査を欠く)・「－」(事実のないもの)・「X」(秘匿)・「nc」(計算不能)
は NULL にする。主産県だけを調べる年は、それ以外の県が「…」になる。

データソース: 農林水産省 作物統計調査 作況調査（野菜）
https://www.e-stat.go.jp/statistics/00500215
"""

import json
import logging
import re
import unicodedata
import urllib.parse
from pathlib import Path

from pipelines import EstatStatus, check_latest_year
from pipelines.school import NATIONWIDE_CODE, PREFECTURES, _fetch

logger = logging.getLogger("pipelines")

API_URL = "https://api.e-stat.go.jp/rest/3.0/app/json"
STATS_CODE = "00500215"
PAGE_LIMIT = 100000

FIRST_YEAR = 2003
# N 年産の確報は N+2 年の春までに出る (令和6年産は 2026 年)。
LATEST_LAG_YEARS = 2

STATISTICS_NAME_RE = re.compile(
    r"^作物統計調査 作況調査\(野菜\) 確報 (平成|令和)(\d+|元)年産野菜生産出荷統計$"
)
TITLE_KEY = "都道府県別の作付面積"
ERA_BASE = {"平成": 1988, "令和": 2018}

MEASURES = {
    "作付面積": ("planted_area_ha", "ha"),
    "10a当たり収量": ("yield_kg_per_10a", "kg"),
    "収穫量": ("harvest_t", "t"),
    "出荷量": ("shipment_t", "t"),
}
UNITS = dict(MEASURES.values())
# 長いものから当てる (「秋冬」を「秋」より先に、「冬春」を「冬」より先に)。
SEASONS = sorted(
    [
        "春",
        "夏",
        "秋",
        "冬",
        "春夏",
        "夏秋",
        "秋冬",
        "冬春",
        "春植え",
        "秋植え",
        "その他",
        "温室",
    ],
    key=len,
    reverse=True,
)
TOTAL = "計"
# 年で表記が揺れる品目名をそろえる。
CROP_ALIASES = {"ばれいしょ(じゃがいも)": "ばれいしょ"}
NUMBER_RE = re.compile(r"^\*?(\d+(?:\.\d+)?)$")
SUBSET_RE = re.compile(r"(?:の)?うち、?")


def _norm(s) -> str:
    return unicodedata.normalize("NFKC", str(s or "")).strip()


def _as_list(x) -> list:
    return [] if x is None else x if isinstance(x, list) else [x]


def _api(app_id: str, method: str, **params) -> dict:
    query = urllib.parse.urlencode({"appId": app_id, **params})
    body = json.loads(_fetch(f"{API_URL}/{method}?{query}"))
    root = next(iter(body.values()))
    status = int(root["RESULT"]["STATUS"])
    if status not in (EstatStatus.OK, EstatStatus.PARTIAL):
        raise RuntimeError(
            f"{method} {params}: status {status}: {root['RESULT'].get('ERROR_MSG')}"
        )
    return root


def survey_year(statistics_name: str) -> int | None:
    """統計名から年産 (西暦) を返す。対象外の統計名なら None。"""
    m = STATISTICS_NAME_RE.match(_norm(statistics_name))
    if not m:
        return None
    return ERA_BASE[m[1]] + (1 if m[2] == "元" else int(m[2]))


def catalog(app_id: str) -> list[tuple[int, str, str]]:
    """都道府県別の表を (年産, 統計表 ID, 表題) で集める。"""
    root = _api(app_id, "getStatsList", statsCode=STATS_CODE, limit=PAGE_LIMIT)
    if root.get("DATALIST_INF", {}).get("RESULT_INF", {}).get("NEXT_KEY"):
        raise RuntimeError(f"getStatsList: {STATS_CODE} が {PAGE_LIMIT} 件に収まらない")
    tables = {
        t["@id"]: (
            year,
            _norm(t["TITLE"]["$"] if isinstance(t["TITLE"], dict) else t["TITLE"]),
        )
        for t in _as_list(root["DATALIST_INF"].get("TABLE_INF"))
        if (year := survey_year(t.get("STATISTICS_NAME")))
        and TITLE_KEY
        in _norm(t["TITLE"]["$"] if isinstance(t["TITLE"], dict) else t["TITLE"])
    }
    found = sorted((year, id_, title) for id_, (year, title) in tables.items())
    years = sorted({y for y, _, _ in found})
    if not years:
        raise RuntimeError(f"getStatsList に {STATS_CODE} の都道府県別の表が無い")
    check_latest_year(years[-1], LATEST_LAG_YEARS)
    # 平成15年産は平成16年産の表の time にしか無いので、表は 2004 年から。
    if missing := [y for y in range(FIRST_YEAR + 1, years[-1] + 1) if y not in years]:
        raise RuntimeError(f"都道府県別の表が欠けている年産: {missing}")
    return found


def _full_name(pref: str) -> str:
    return pref + (
        ""
        if pref == "北海道"
        else "都"
        if pref == "東京"
        else "府"
        if pref in ("京都", "大阪")
        else "県"
    )


def prefecture(name: str) -> tuple[str, str | None, str] | None:
    """地域名から (標準地域コード, 都道府県コード, 正式名) を返す。全国は (00000, None, 全国)。

    全国農業地域・農政局は None。「北海道（農業地域）」「（全国農業地域）_北海道」は
    都道府県の北海道と取り違えない。
    """
    s = _norm(name).removeprefix("(都道府県)_")
    if s == "全国":
        return NATIONWIDE_CODE, None, "全国"
    for index, pref in enumerate(PREFECTURES, start=1):
        if s in (pref, _full_name(pref)):
            return f"{index:02d}000", f"{index:02d}", _full_name(pref)
    return None


def split_subset(s: str) -> tuple[str, str | None]:
    """「夏秋トマトのうち、加工用トマト」を (夏秋トマト, 加工用トマト) に分ける。"""
    head, *rest = SUBSET_RE.split(s, maxsplit=1)
    return head.strip(), (rest[0].strip() or None) if rest else None


def season_of(word: str, crop: str) -> str:
    """「春キャベツ」「春」「温室メロン(アールスフェボリット系)」から作型を返す。"""
    w = re.sub(r"\(.*\)$", "", word).removesuffix(crop) or TOTAL
    if w != TOTAL and w not in SEASONS:
        raise ValueError(f"作型が読めない: {word!r} ({crop})")
    return w


def parse_item(name: str, crops: set[str]) -> tuple[str, str, str | None]:
    """全品目の表の品目名「春キャベツ」を (品目, 作型, うち内訳) にする。"""
    head, subset = split_subset(_norm(name))
    for season in SEASONS:
        if head.startswith(season) and head[len(season) :] in crops:
            crop = head[len(season) :]
            return CROP_ALIASES.get(crop, crop), season, subset
    return CROP_ALIASES.get(head, head), TOTAL, subset


def _title_tokens(title: str) -> list[str]:
    # 先頭は「、10a当たり収量、収穫量及び出荷量」の残りなので捨てる。
    return _norm(title).split(TITLE_KEY, 1)[1].replace("(つづき)", "").split()[1:]


def parse_title_crop(title: str) -> str:
    token = _title_tokens(title)[0]
    return CROP_ALIASES.get(token, token)


def parse_title(title: str) -> tuple[str, str, str | None]:
    """1 品目の表の表題の末尾「… キャベツ 夏秋」を (品目, 作型, うち内訳) にする。

    令和3年産以降の末尾「キャベツ 計、春、夏秋、冬」は parse_title_crop で読む。
    """
    tokens = _title_tokens(title)
    crop = CROP_ALIASES.get(tokens[0], tokens[0])
    head, subset = split_subset(" ".join(tokens[1:]))
    words = head.split()
    return crop, season_of(words[-1], crop) if words else TOTAL, subset


def parse_value(s: str) -> float | None:
    m = NUMBER_RE.match(_norm(s).replace(",", ""))
    return float(m[1]) if m else None


def _axes(class_inf: dict) -> dict[str, dict]:
    """CLASS_OBJ を役割 (area / time / item / measure) ごとに {コード: 名前} で返す。"""
    axes: dict[str, dict] = {}
    for obj in _as_list(class_inf["CLASS_OBJ"]):
        codes = {c["@code"]: _norm(c["@name"]) for c in _as_list(obj["CLASS"])}
        name = _norm(obj["@name"])
        role = (
            "time"
            if obj["@id"] == "time"
            else "area"
            if obj["@id"] == "area" or "地域" in name or "都道府県" in name
            else "item"
            if "品目" in name
            else "measure"
        )
        if role in axes:
            raise RuntimeError(f"{role} の軸が 2 つある: {obj['@id']} {name}")
        axes[role] = {"id": obj["@id"], "codes": codes}
    if {"area", "measure"} - axes.keys():
        raise RuntimeError(f"地域か項目の軸が無い: {list(axes)}")
    return axes


def measure_of(name: str) -> tuple[str, str, str | None] | None:
    """項目名「春_収穫量」から (列名, 作型, うち内訳) を返す。

    「対前年産比_収穫量」(令和) や「前年産対比_収穫量」(平成16年産) のように、作型でも
    うち内訳でもない接頭辞が付く比率の項目は None。
    """
    *prefix, last = name.split("_")
    known = [p in SEASONS or p == TOTAL or p.startswith("うち") for p in prefix]
    if last not in MEASURES or not all(known):
        return None
    subsets = [p.removeprefix("うち") for p in prefix if p.startswith("うち")]
    seasons = [p for p in prefix if not p.startswith("うち")]
    return (
        MEASURES[last][0],
        seasons[0] if seasons else TOTAL,
        subsets[0] if subsets else None,
    )


def parse_table(data: dict, year: int, title: str, years: set[int]) -> list[dict]:
    """getStatsData の STATISTICAL_DATA を 1 値 1 行の dict にする。"""
    axes = _axes(data["CLASS_INF"])
    area_of = {code: prefecture(name) for code, name in axes["area"]["codes"].items()}
    measure = {
        code: measure_of(name) for code, name in axes["measure"]["codes"].items()
    }
    crops = {_norm(n) for n in axes.get("item", {}).get("codes", {}).values()}
    # 令和3年産以降は作型・うち内訳が項目名の接頭辞にあるので、表題からは品目だけ取る。
    prefixed = any("_" in n for n in axes["measure"]["codes"].values())
    title_item = (
        None
        if "item" in axes
        else (parse_title_crop(title), TOTAL, None)
        if prefixed
        else parse_title(title)
    )

    rows = []
    for v in _as_list(data["DATA_INF"]["VALUE"]):
        area = area_of[v["@" + axes["area"]["id"]]]
        m = measure[v["@" + axes["measure"]["id"]]]
        if area is None or m is None:
            continue
        column, m_season, m_subset = m
        if _norm(v.get("@unit")) != UNITS[column]:
            raise RuntimeError(f"{year} {title}: {column} の単位が {v.get('@unit')}")
        if "time" in axes:
            value_year = int(v["@time"][:4])
            # 前年の値は、その年産の表が無いとき (平成15年産) だけ使う。
            if value_year != year and value_year in years:
                continue
        else:
            value_year = year
        if "item" in axes:
            item = axes["item"]["codes"][v["@" + axes["item"]["id"]]]
            crop, season, subset = parse_item(item, crops)
        else:
            crop, t_season, t_subset = title_item
            season = m_season if m_season != TOTAL else t_season
            subset = m_subset or t_subset
        rows.append(
            {
                "year": value_year,
                "crop": crop,
                "season": season,
                "subset": subset,
                "area": area[0],
                "prefecture_code": area[1],
                "area_name": area[2],
                "column": column,
                "value": parse_value(v["$"]),
            }
        )
    return rows


KEY = ("year", "crop", "season", "subset", "area", "prefecture_code", "area_name")


def widen(rows: list[dict]) -> list[dict]:
    """1 値 1 行を、キーごとに 4 項目を列に並べた 1 行にする。

    同じ地域が 1 つの表に 2 回現れることがある (農業地域の北海道・沖縄と都道府県の
    北海道・沖縄が同じ名前で並ぶ年)。値が同じならどちらを取っても同じなので 1 つに
    する。値が違えば当て違いなので、食い違いをすべて挙げて止める。
    """
    out: dict[tuple, dict] = {}
    source: dict[tuple, str] = {}
    conflicts = []
    for r in rows:
        key = tuple(r[k] for k in KEY)
        rec = out.setdefault(key, dict(zip(KEY, key)))
        if r["column"] in rec and rec[r["column"]] != r["value"]:
            conflicts.append(
                f"{key} {r['column']}: {rec[r['column']]} ({source[key + (r['column'],)]})"
                f" / {r['value']} ({r['table']})"
            )
        rec.setdefault(r["column"], r["value"])
        source.setdefault(key + (r["column"],), r["table"])
    if conflicts:
        raise RuntimeError(
            f"同じキーに違う値が {len(conflicts)} 件:\n" + "\n".join(conflicts[:50])
        )
    return [{c: None for c, _ in MEASURES.values()} | rec for rec in out.values()]


def fetch_table(app_id: str, stats_data_id: str, cache_dir: Path | None = None) -> dict:
    """統計表を取得する。cache_dir を渡すと応答を保存し、次からはそれを読む (手元の試行用)。"""
    cached = cache_dir / f"{stats_data_id}.json" if cache_dir else None
    if cached and cached.exists():
        return json.loads(cached.read_text(encoding="utf-8"))
    root = _api(app_id, "getStatsData", statsDataId=stats_data_id, limit=PAGE_LIMIT)
    data = root["STATISTICAL_DATA"]
    if data.get("RESULT_INF", {}).get("NEXT_KEY"):
        raise RuntimeError(f"getStatsData {stats_data_id}: {PAGE_LIMIT} 件に収まらない")
    if cached:
        cached.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return data


def build_crop(dest_dir: str, app_id: str, cache_dir: str | None = None) -> None:
    """野菜の都道府県別の表を取得し、NDJSON に整形する。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)
    cache = Path(cache_dir) if cache_dir else None
    if cache:
        cache.mkdir(parents=True, exist_ok=True)

    tables = catalog(app_id)
    years = {y for y, _, _ in tables}
    rows: list[dict] = []
    for year, id_, title in tables:
        parsed = parse_table(fetch_table(app_id, id_, cache), year, title, years)
        if not parsed:
            raise RuntimeError(
                f"{year} {id_} {title}: 全国・都道府県の値が 1 つも読めない"
            )
        rows += [r | {"table": id_} for r in parsed]
    records = widen(rows)

    with (dest / "vegetable_prefecture.ndjson").open("w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
    got = sorted({r["year"] for r in records})
    logger.info(
        f"  vegetable_prefecture={len(records)} rows, {got[0]}-{got[-1]}年産, {len(tables)} tables"
    )
