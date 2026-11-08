"""watch_stats.yml の統計に、新しい統計表が公開されていないかを見る。

過去 7 日（--days で変えられる）に公開された統計表を getStatsList で探し、あれば
統計ごとに issue を立てる。同じ題の issue が開いていれば立て直さない。
取り込み済みの表の更新は check_local_updates.py が見るので、ここでは公開日で絞る。

    ESTAT_API_KEY=... python scripts/check_new_tables.py
    ESTAT_API_KEY=... python scripts/check_new_tables.py --dry-run --days 60

依存は標準ライブラリと PyYAML、issue を立てる gh だけ。
"""

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
API = "https://api.e-stat.go.jp/rest/3.0/app/json/getStatsList"
LIMIT = 100


def as_list(x) -> list:
    return [] if x is None else [x] if isinstance(x, dict) else x


def text(x) -> str:
    """e-Stat の値は文字列か {"@code": ..., "$": ...} のどちらか。"""
    return x.get("$", "") if isinstance(x, dict) else str(x or "")


def fetch_page(app_id: str, stats_code: str, search_kind: int, since: dt.date, until: dt.date, start: int) -> dict:
    query = urllib.parse.urlencode(
        {
            "appId": app_id,
            "statsCode": stats_code,
            "searchKind": search_kind,
            "updatedDate": f"{since:%Y%m%d}-{until:%Y%m%d}",
            "limit": LIMIT,
            "startPosition": start,
        }
    )
    with urllib.request.urlopen(f"{API}?{query}", timeout=120) as res:
        body = json.load(res)["GET_STATS_LIST"]
    status = int(body["RESULT"]["STATUS"])
    # 1 = 該当なし
    if status not in (0, 1, 2):
        raise RuntimeError(f"{stats_code}: e-Stat がエラー {status} を返した: {body['RESULT']['ERROR_MSG']}")
    return body.get("DATALIST_INF", {})


def tables(app_id: str, stats_code: str, search_kind: int, since: dt.date, until: dt.date) -> list[dict]:
    """since〜until に更新された統計表。ページを最後までたどる。"""
    out, start = [], 1
    while True:
        listing = fetch_page(app_id, stats_code, search_kind, since, until, start)
        out += as_list(listing.get("TABLE_INF"))
        next_key = listing.get("RESULT_INF", {}).get("NEXT_KEY")
        if not next_key:
            return out
        start = int(next_key)


def new_tables(app_id: str, stat: dict, since: dt.date, until: dt.date) -> list[dict]:
    """since 以降に公開された（更新ではなく新しく出た）統計表。"""
    found = [
        t
        for kind in stat.get("search_kinds", [1])
        for t in tables(app_id, stat["stats_code"], kind, since, until)
    ]
    return [t for t in found if text(t.get("OPEN_DATE")) >= f"{since:%Y-%m-%d}"]


def describe(t: dict) -> str:
    stat_name = text(t.get("STATISTICS_NAME"))
    title = text(t.get("TITLE"))
    return f"- {t['@id']}（公開 {text(t.get('OPEN_DATE'))}、調査 {text(t.get('SURVEY_DATE'))}）{stat_name} {title}"


def issue_body(stat: dict, found: list[dict], since: dt.date, until: dt.date) -> str:
    lines = sorted({describe(t) for t in found})
    shown = lines[:100]
    rest = len(lines) - len(shown)
    return "\n".join(
        [
            f"{stat['title']}（{stat['stats_code']}）に、{since}〜{until} に公開された統計表が {len(lines)} 件あります。",
            "取り込むかどうかを決め、取り込むなら tables.yml か local_tables.yml に足してください。",
            "",
            *shown,
            *([f"- ほか {rest} 件"] if rest else []),
            "",
            f"一覧: https://www.e-stat.go.jp/stat-search/database?toukei={stat['stats_code']}",
        ]
    )


def open_issue_exists(title: str) -> bool:
    out = subprocess.run(
        ["gh", "issue", "list", "--state", "open", "--search", f'"{title}" in:title', "--json", "title"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return any(i["title"] == title for i in json.loads(out))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--days", type=int, default=7)
    args = parser.parse_args()
    app_id = os.environ["ESTAT_API_KEY"]
    until = dt.date.today() - dt.timedelta(days=1)
    since = until - dt.timedelta(days=args.days - 1)
    watched = yaml.safe_load((ROOT / "watch_stats.yml").read_text())["stats"]
    # 1 つの統計で e-Stat が答えなくても、残りは見る。失敗は最後に終了コードで知らせる
    failed = []
    for stat in watched:
        try:
            found = new_tables(app_id, stat, since, until)
        except Exception as e:
            print(f"{stat['title']}: 取得できなかった: {e}", file=sys.stderr)
            failed.append(stat["stats_code"])
            continue
        if not found:
            print(f"{stat['title']}: 新しい表なし")
            continue
        title = f"e-Stat に新しい統計表: {stat['title']}（{since}〜{until}）"
        body = issue_body(stat, found, since, until)
        print(f"{stat['title']}: {len(found)} 件\n{body}")
        if args.dry_run or open_issue_exists(title):
            continue
        subprocess.run(["gh", "issue", "create", "--title", title, "--body", body], check=True)
    if failed:
        raise SystemExit(f"取得できなかった統計: {failed}")


if __name__ == "__main__":
    main()
