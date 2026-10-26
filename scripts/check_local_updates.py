"""手元で取り込んだ統計表 (local_tables.yml) の e-Stat 側の更新日を見張る。

CI の Sync はこれらの表を e-Stat から取らないので、e-Stat 側で直されても気付けない。
毎週 e-Stat の更新日を記録と比べ、変わった表があればグループごとに issue を立てる。
同じ題の issue が開いていれば立て直さない。

    ESTAT_API_KEY=... python scripts/check_local_updates.py          # 比べて issue を立てる
    ESTAT_API_KEY=... python scripts/check_local_updates.py --dry-run

依存は標準ライブラリと PyYAML、issue を立てる gh だけ。プロジェクトの依存
(dbt・dlt) を入れずに数十秒で回すため。
"""

import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
API = "https://api.e-stat.go.jp/rest/3.0/app/json/getStatsData"
CATALOG_API = "https://api.e-stat.go.jp/rest/3.0/app/json/getDataCatalog"


def updated_date(app_id: str, stats_data_id: str) -> str:
    """統計表の更新日を返す。データは 1 件だけ、メタ情報は付けずに取る。"""
    query = urllib.parse.urlencode(
        {"appId": app_id, "statsDataId": stats_data_id, "limit": 1, "metaGetFlg": "N"}
    )
    with urllib.request.urlopen(f"{API}?{query}", timeout=120) as res:
        body = json.load(res)["GET_STATS_DATA"]
    status = int(body["RESULT"]["STATUS"])
    if status != 0:
        raise RuntimeError(f"{stats_data_id}: e-Stat がエラー {status} を返した: {body['RESULT']['ERROR_MSG']}")
    return body["STATISTICAL_DATA"]["TABLE_INF"]["UPDATED_DATE"]


def catalog_modified_date(app_id: str, stats_code: str) -> str:
    """統計表ファイルで配られる統計の、全ファイルの最終更新日の最大。

    新しい年度のファイルが出ても、過去のファイルが直っても進む。
    pipelines/kaigo_insurance.py の catalog_modified_date と同じ定義。
    """
    latest = ""
    start = 1
    while True:
        query = urllib.parse.urlencode(
            {"appId": app_id, "statsCode": stats_code, "limit": 100, "startPosition": start}
        )
        with urllib.request.urlopen(f"{CATALOG_API}?{query}", timeout=120) as res:
            body = json.load(res)["GET_DATA_CATALOG"]
        status = int(body["RESULT"]["STATUS"])
        if status not in (0, 2):
            raise RuntimeError(f"{stats_code}: e-Stat がエラー {status} を返した: {body['RESULT']['ERROR_MSG']}")
        listing = body["DATA_CATALOG_LIST_INF"]
        items = listing["DATA_CATALOG_INF"]
        for item in [items] if isinstance(items, dict) else items:
            resources = item["RESOURCES"]["RESOURCE"]
            for r in [resources] if isinstance(resources, dict) else resources:
                latest = max(latest, r["LAST_MODIFIED_DATE"])
        next_key = listing.get("RESULT_INF", {}).get("NEXT_KEY")
        if not next_key:
            return latest
        if int(next_key) <= start:
            raise RuntimeError(f"{stats_code}: NEXT_KEY {next_key} が startPosition {start} から進まない")
        start = int(next_key)


def changed_tables(app_id: str, group: dict) -> list[str]:
    if "stats_code" in group:
        # 統計表ファイルで配られる統計 (fetcher のあるグループ)。表ごとの更新日が無いので
        # 統計全体の最終更新日で見る
        now = catalog_modified_date(app_id, group["stats_code"])
        # YAML で引用符を落とすと date になるので、文字列に揃えて比べる
        if now == str(group["catalog_modified_date"]):
            return []
        return [f"- 統計表ファイル（{group['stats_code']}）: {group['catalog_modified_date']} → {now}"]
    lines = []
    for t in group["tables"]:
        now = updated_date(app_id, t["stats_data_id"])
        # YAML で引用符を落とすと updated_date が date になるので、文字列に揃えて比べる
        if now != str(t["updated_date"]):
            lines.append(f"- {t['name']}（{t['stats_data_id']}）: {t['updated_date']} → {now}")
    return lines


def issue_body(name: str, group: dict, lines: list[str]) -> str:
    return "\n".join(
        [
            f"{group['title']}（local_tables.yml の {name}）の統計表が e-Stat で更新されました。",
            "",
            *lines,
            "",
            "取り込み直す手順:",
            "",
            "1. local_tables.yml の updated_date（統計表ファイルのグループは catalog_modified_date と各表の updated_date）を新しい日付に直す",
            f"2. `uv run --env-file .env python load_local.py fetch {name}`",
            "3. CI の Sync が走っていないときに `uv lock --upgrade-package queria && uv sync` のあと "
            f"`QUERIA_TOKEN=... uv run --env-file .env queria sync -- uv run --env-file .env python load_local.py load {name}`",
            "4. 1 の変更を PR にする",
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
    dry_run = "--dry-run" in sys.argv[1:]
    app_id = os.environ["ESTAT_API_KEY"]
    groups = yaml.safe_load((ROOT / "local_tables.yml").read_text())["groups"]
    # 1 つのグループで e-Stat が答えなくても (障害、表の差し替えで ID が消えた など)、
    # 残りのグループは見て issue を立てる。失敗は最後に終了コードで知らせる
    failed = []
    for name, group in groups.items():
        try:
            lines = changed_tables(app_id, group)
        except Exception as e:
            print(f"{name}: 更新日を取れなかった: {e}", file=sys.stderr)
            failed.append(name)
            continue
        if not lines:
            print(f"{name}: 変わりなし")
            continue
        title = f"e-Stat の統計表が更新された: {name}"
        body = issue_body(name, group, lines)
        print(f"{name}: 更新あり\n{body}")
        if dry_run or open_issue_exists(title):
            continue
        subprocess.run(["gh", "issue", "create", "--title", title, "--body", body], check=True)
    if failed:
        raise SystemExit(f"更新日を取れなかったグループ: {failed}")


if __name__ == "__main__":
    main()
