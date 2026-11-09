"""e-Stat の統計分類（産業分類以外）の取得。

e-Stat の「統計分類・用語の検索」で公開されている統計分類を、改定ごとに CSV で
ダウンロードし、dbt が読み込める NDJSON に整形する。ダウンロードの方法は
industry_code と同じ（画面のダウンロードボタンと同じ /term/download を叩く）。

- occupation:              日本標準職業分類（平成21年・平成9年）
- commodity:               日本標準商品分類（平成2年）
- icd10:                   疾病、傷害及び死因の統計分類 基本分類（ICD-10 2013年版・2003年版・1994年）
- icd10_disease:           同 疾病分類（大分類表・中分類表・小分類表）
- icd10_cause_of_death:    同 死因分類
- industry_economic_census: 経済センサス産業分類（平成26年・平成21年 経済センサス‐基礎調査）

データソース: 政府統計の総合窓口(e-Stat) 統計分類・用語の検索
https://www.e-stat.go.jp/classifications/terms
"""

import csv
import io
import json
import logging
import re
from collections.abc import Callable, Iterable
from pathlib import Path
from urllib.parse import urlencode

from pipelines.industry_code import DOWNLOAD_URL, _download_params
from pipelines.municipality_code import _fetch

logger = logging.getLogger("pipelines")

# 商品分類の CSV は 1.6MB あり、e-Stat が返し始めるまで 1 分を超えることがある
_TIMEOUT = 300


def _clean(value: str) -> str | None:
    s = value.replace("\r\n", "\n").strip()
    return s or None


def _code(value: str) -> str:
    # セル内の改行と引用符が混じることがある（industry_code の 2425 と同じ崩れ）
    return re.sub(r'[\r\n"]', "", value).strip()


def _rows(text: str, header: list[str], name: str) -> list[list[str]]:
    """1行目のタイトルと2行目のヘッダーを確かめ、コードが空の注記行を除いて返す。"""
    rows = [r for r in csv.reader(io.StringIO(text)) if r]
    if len(rows) < 2 or rows[1] != header:
        raise SystemExit(f"{name} の CSV のヘッダーが想定外: {rows[1:2]}")
    body = rows[2:]
    bad = [r for r in body if len(r) != len(header)]
    if bad:
        raise SystemExit(f"{name} で列数が想定外の行: {bad[:3]}")
    return [r for r in body if _code(r[0])]


# --- 職業分類・経済センサス産業分類（大分類が英字、以下が数字の桁で決まる） ---

_JSIC_LIKE_HEADER = ["分類コード", "項目名", "項目の説明", "事例", "不適合事例"]
_CENSUS_HEADER = ["分類コード", "項目名", "項目の説明"]


def _alpha_level(code: str) -> str:
    if re.fullmatch(r"[A-Z]", code):
        return "major"
    # 平成9年の職業分類は大分類 I を I-1〜I-3 に分けている
    if re.fullmatch(r"[A-Z]-\d", code):
        return "major_group"
    if re.fullmatch(r"\d{2}", code):
        return "middle"
    if re.fullmatch(r"\d{3}|\d{2}[A-Z]", code):
        return "minor"
    if re.fullmatch(r"\d{4}", code):
        return "detail"
    raise SystemExit(f"分類コードの書式が想定外: {code!r}")


def _alpha_hierarchy(codes: Iterable[str]) -> list[tuple[str, str | None, str]]:
    """(level, parent_code, major_code) を返す。

    中分類の親（大分類）はコードから導けないので、大分類の直後にその中分類以下が
    並ぶ並び順から取る。小分類・細分類の親はコードの先頭を切って求める。
    """
    out = []
    major = None
    upper = None  # 中分類の親になる直近の大分類（または大分類の区分）
    for code in codes:
        level = _alpha_level(code)
        if level == "major":
            major = upper = code
        elif level == "major_group":
            if code[0] != major:
                raise SystemExit(f"大分類の区分が大分類の後に無い: {code}")
            upper = code
        if major is None:
            raise SystemExit(f"大分類より前に行がある: {code}")
        parent = {"major": None, "major_group": major, "middle": upper}.get(
            level, code[:-1]
        )
        out.append((level, parent, major))
    return out


def _parse_occupation(text: str, revision: int) -> list[dict]:
    rows = _rows(text, _JSIC_LIKE_HEADER, f"職業分類 {revision}")
    codes = [_code(r[0]) for r in rows]
    return [
        {
            "revision": revision,
            "level": level,
            "code": code,
            "name": _clean(r[1]),
            "parent_code": parent,
            "major_code": major,
            "description": _clean(r[2]),
            "examples": _clean(r[3]),
            "non_examples": _clean(r[4]),
        }
        for r, code, (level, parent, major) in zip(rows, codes, _alpha_hierarchy(codes))
    ]


def _parse_economic_census(text: str, revision: int) -> list[dict]:
    rows = _rows(text, _CENSUS_HEADER, f"経済センサス産業分類 {revision}")
    codes = [_code(r[0]) for r in rows]
    return [
        {
            "revision": revision,
            "level": level,
            "code": code,
            "name": _clean(r[1]),
            "parent_code": parent,
            "major_code": major,
            "description": _clean(r[2]),
        }
        for r, code, (level, parent, major) in zip(rows, codes, _alpha_hierarchy(codes))
    ]


# --- 商品分類（桁数が階層。再掲の行は除く） ---


def _commodity_parents(codes: list[str]) -> list[str | None]:
    """各コードの親。

    大分類（1桁）の下の中分類（2桁）は先頭の数字が大分類と一致しない（大分類 1 の下に
    01 が並ぶ）ので、並び順から直前の大分類を取る。3桁以上は、それより前に出た
    コードのうち先頭が一致する直近のものを親にする。途中の桁の分類が無いことがあるので
    1桁短いとは限らない。
    """
    parents: list[str | None] = []
    major = None
    stack: list[str] = []
    for code in codes:
        if len(code) == 1:
            major, stack = code, []
            parents.append(None)
            continue
        while stack and not code.startswith(stack[-1]):
            stack.pop()
        parents.append(stack[-1] if stack else major)
        stack.append(code)
    return parents


def _parse_commodity(text: str, revision: int) -> list[dict]:
    rows = _rows(text, ["分類コード", "項目名", "本籍"], f"商品分類 {revision}")
    items = [r for r in rows if _code(r[0]) != "再掲"]
    codes = [_code(r[0]) for r in items]
    bad = [c for c in codes if not re.fullmatch(r"\d{1,10}", c)]
    if bad:
        raise SystemExit(f"商品分類のコードの書式が想定外: {bad[:10]}")
    return [
        {
            "revision": revision,
            "level": len(code),
            "code": code,
            "name": _clean(r[1]),
            "parent_code": parent,
        }
        for r, code, parent in zip(items, codes, _commodity_parents(codes))
    ]


# --- ICD-10 基本分類（章・中間分類・3桁・4桁・5桁） ---

_RANGE = re.compile(r"([A-Z]\d\d)\s*[-－]\s*([A-Z]\d\d)")
_ICD_RANK = {"chapter": 1, "block": 2, "category": 3, "subcategory": 4, "detail": 5}


def _icd_core(code: str) -> str:
    """剣印（†）と星印（*）を落としたコード。親子の判定に使う。"""
    return code.rstrip("†*")


def _icd_level(code: str) -> str:
    core = _icd_core(code)
    if re.fullmatch(r"[IVXL]+", core):
        return "chapter"
    # 2003年版には後ろの英字が抜けた "U80-89" がある
    if re.fullmatch(r"[A-Z]\d\d-[A-Z]?\d\d", core):
        return "block"
    if re.fullmatch(r"[A-Z]\d\d[a-z]?", core):
        return "category"
    if re.fullmatch(r"[A-Z]\d\d[a-z]?\.\d[a-z]?", core):
        return "subcategory"
    if re.fullmatch(r"[A-Z]\d\d[a-z]?\.(\d\d|-\d)", core):
        return "detail"
    raise SystemExit(f"ICD-10 のコードの書式が想定外: {code!r}")


def _icd_span(code: str, name: str, level: str) -> tuple[str, str]:
    """その行が覆う3桁コードの範囲。章は名称の括弧書き、中間分類はコードから取る。"""
    if level == "chapter":
        m = _RANGE.search(name)
        # 2003年版の XXII 特殊目的用コードは名称に範囲が無い。U から始まる最後の章
        if not m and code == "XXII":
            return "U00", "U99"
        if not m:
            raise SystemExit(f"ICD-10 の章の名称に範囲が無い: {code} {name}")
        return m.group(1), m.group(2)
    if level == "block":
        lo, hi = _icd_core(code).split("-")
        return lo, hi if hi[0].isalpha() else lo[0] + hi
    return _icd_core(code)[:3], _icd_core(code)[:3]


def _icd_contains(outer: dict, inner: dict) -> bool:
    """outer が inner の祖先になり得るか。章と中間分類は範囲、それより下はコードの先頭で見る。"""
    if outer["level"] in ("chapter", "block"):
        same_block = inner["level"] == outer["level"] == "block" and (
            outer["lo"],
            outer["hi"],
        ) == (inner["lo"], inner["hi"])
        return (
            inner["level"] != "chapter"
            and not same_block
            and outer["lo"] <= inner["lo"]
            and inner["hi"] <= outer["hi"]
        )
    return _ICD_RANK[inner["level"]] > _ICD_RANK[outer["level"]] and _icd_core(
        inner["code"]
    ).startswith(_icd_core(outer["code"]))


def _parse_icd10(text: str, revision: int) -> list[dict]:
    rows = _rows(text, ["分類コード", "項目名"], f"ICD-10 基本分類 {revision}")
    items = [
        {"code": code, "name": _clean(r[1]), "level": level}
        | dict(zip(("lo", "hi"), _icd_span(code, r[1], level)))
        for r in rows
        for code in [_code(r[0])]
        for level in [_icd_level(code)]
    ]
    records = []
    stack: list[dict] = []
    chapter = None
    for item in items:
        while stack and not _icd_contains(stack[-1], item):
            stack.pop()
        if item["level"] == "chapter":
            chapter = item["code"]
        elif not stack:
            raise SystemExit(f"ICD-10 {revision} で親の見つからない行: {item['code']}")
        records.append(
            {
                "revision": revision,
                "level": item["level"],
                "code": item["code"],
                "name": item["name"],
                "parent_code": stack[-1]["code"] if stack else None,
                "chapter_code": chapter,
            }
        )
        stack.append(item)
    return records


# --- ICD-10 疾病分類・死因分類（基本分類コードの範囲を持つ集計用の分類） ---

_ICD_GROUP_HEADER = ["分類コード", "項目名", "基本分類コード"]
_DISEASE_TABLES = {"a": "major", "b": "middle", "c": "minor"}


def _parse_icd10_disease(text: str, revision: int) -> list[dict]:
    """疾病分類表。a-・b-・c- はそれぞれ大分類表・中分類表・小分類表で、別々の表。

    各表のコードは4桁で、下2桁が 00 の行が章、それ以外はその章の項目。
    """
    rows = _rows(text, _ICD_GROUP_HEADER, f"ICD-10 疾病分類 {revision}")
    records = []
    for r in rows:
        code = _code(r[0])
        m = re.fullmatch(r"([abc])-(\d{2})(\d{2})", code)
        if not m:
            raise SystemExit(f"疾病分類のコードの書式が想定外: {code!r}")
        prefix, chapter, item = m.groups()
        records.append(
            {
                "revision": revision,
                "table_kind": _DISEASE_TABLES[prefix],
                "code": code,
                "name": _clean(r[1]),
                "parent_code": None if item == "00" else f"{prefix}-{chapter}00",
                "icd10_codes": _clean(r[2]),
            }
        )
    return records


def _parse_icd10_cause_of_death(text: str, revision: int) -> list[dict]:
    """死因分類。5桁で、下3桁が 000 の行が章、下2桁が 00 の行が中間の項目。"""
    rows = _rows(text, _ICD_GROUP_HEADER, f"ICD-10 死因分類 {revision}")
    codes = {_code(r[0]) for r in rows}

    def parent(code: str) -> str | None:
        if code.endswith("000"):
            return None
        mid = code[:3] + "00"
        return mid if not code.endswith("00") and mid in codes else code[:2] + "000"

    bad = [c for c in codes if not re.fullmatch(r"\d{5}", c)]
    if bad:
        raise SystemExit(f"死因分類のコードの書式が想定外: {bad[:10]}")
    return [
        {
            "revision": revision,
            "code": code,
            "name": _clean(r[1]),
            "parent_code": parent(code),
            "icd10_codes": _clean(r[2]),
        }
        for r in rows
        for code in [_code(r[0])]
    ]


# --- 取得 ---

Parser = Callable[[str, int], list[dict]]

# テーブル名 → (e-Stat の分類番号 bKbn, {改定番号 kaiteiCode: 改定年}, 整形)
CLASSIFICATIONS: dict[str, tuple[str, dict[str, int], Parser]] = {
    "occupation": ("20", {"02": 2009, "01": 1997}, _parse_occupation),
    "commodity": ("30", {"01": 1990}, _parse_commodity),
    "icd10": ("40", {"03": 2013, "02": 2003, "01": 1994}, _parse_icd10),
    "icd10_disease": (
        "50",
        {"03": 2013, "02": 2003, "01": 1994},
        _parse_icd10_disease,
    ),
    "icd10_cause_of_death": (
        "60",
        {"03": 2013, "02": 2003, "01": 1994},
        _parse_icd10_cause_of_death,
    ),
    "industry_economic_census": (
        "80",
        {"03": 2014, "01": 2009},
        _parse_economic_census,
    ),
}


def _check(table: str, records: list[dict]) -> None:
    keys = [(r["revision"], r["code"]) for r in records]
    if len(set(keys)) != len(keys):
        raise SystemExit(f"{table} でコードが重複している")
    known = set(keys)
    orphans = [
        r["code"]
        for r in records
        if r["parent_code"] and (r["revision"], r["parent_code"]) not in known
    ]
    if orphans:
        raise SystemExit(f"{table} で親の無いコード: {orphans[:10]}")


def _download(b_kbn: str, kaitei_code: str) -> str:
    params = _download_params(kaitei_code) | {"bKbn": b_kbn}
    return _fetch(f"{DOWNLOAD_URL}?{urlencode(params)}", timeout=_TIMEOUT).decode(
        "utf-8"
    )


def build_classification_code(dest_dir: str) -> None:
    """統計分類を取得し、テーブルごとに NDJSON に整形する。"""
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)

    for table, (b_kbn, revisions, parse) in CLASSIFICATIONS.items():
        records = []
        for kaitei_code, revision in revisions.items():
            logger.info(f"  downloading {table} {revision}")
            text = _download(b_kbn, kaitei_code)
            (dest / f"{table}_{revision}.csv").write_text(text, encoding="utf-8")
            parsed = parse(text, revision)
            logger.info(f"  {table} {revision}: {len(parsed)} rows")
            records.extend(parsed)
        _check(table, records)
        with (dest / f"{table}.ndjson").open("w", encoding="utf-8") as f:
            f.writelines(json.dumps(r, ensure_ascii=False) + "\n" for r in records)
