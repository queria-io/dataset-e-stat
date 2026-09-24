"""パイプライン共通セットアップ。"""

import logging
import logging.config
import os
import tempfile
from datetime import date
from enum import IntEnum
from pathlib import Path

import dlt
from dlt.destinations import ducklake
from dlt.destinations.impl.ducklake.configuration import DuckLakeCredentials


class EstatStatus(IntEnum):
    """e-Stat API レスポンスステータスコード。

    https://www.e-stat.go.jp/api/api-info/e-stat-manual3-0#sec3
    """

    OK = 0  # 正常終了
    NO_DATA = 1  # 正常終了（該当データなし）
    PARTIAL = 2  # 正常終了（条件不一致、部分的な結果）
    # 100+ はエラー


def check_latest_year(latest: int, lag_years: int, today: date | None = None) -> None:
    """取れた最新の調査年が、暦年から lag_years より遅れていないことを確かめる。

    年の連続を見る検査は、上限に取れた最大年を使うので、最新年だけが取れなく
    なると上限もいっしょに下がって素通りする。ここでは上限を暦年から決める。

    調査年 N の表は、N + lag_years 年の 8 月までに出そろう前提で置く。9 月に
    なってもまだ無ければ止める。実測の公表日 (パイプラインが読む表):
    - 介護サービス施設・事業所調査 / 社会福祉施設等調査 (lag_years=2): N+1 年 12 月〜
      N+2 年 1 月。最も遅いのは 2018 年調査の 2020-07-31
    - 地方財政状況調査 (lag_years=1): N+1 年 3 月末。最も遅いのは 2020 年の 2021-05-27
    """
    today = today or date.today()
    expected = today.year - lag_years - (0 if today.month >= 9 else 1)
    if latest < expected:
        raise RuntimeError(
            f"最新の調査年が {latest} で、{today} 時点で出ているはずの {expected} に届かない"
        )


logging.config.dictConfig(
    {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {"plain": {"format": "%(message)s"}},
        "handlers": {
            "console": {"class": "logging.StreamHandler", "formatter": "plain"}
        },
        "loggers": {
            "pipelines": {"level": "INFO", "handlers": ["console"], "propagate": False},
            "dlt.extract.extractors": {"level": "ERROR"},
        },
    }
)

SOURCE_SCHEMA = "_source"


def create_pipeline():
    """dlt パイプラインを queria の DuckLake (SQLite + R2) で構成する。

    queria run が注入する QUERIA_* 環境変数を使う:
    - catalog: ローカル SQLite ライブカタログ (QUERIA_CATALOG_URL = sqlite:///...)
    - storage: Parquet データの保存先 (QUERIA_DATA_URL、R2)
    """
    catalog_url = os.environ["QUERIA_CATALOG_URL"]
    data_url = os.environ["QUERIA_DATA_URL"]

    # DuckLake へのコミットを直列化し、スナップショット採番の競合を防ぐ
    # (SQLite カタログは単一ライター前提)。
    os.environ.setdefault("LOAD__WORKERS", "1")

    storage = data_url
    if data_url.startswith("s3://"):
        from dlt.common.configuration.specs import AwsCredentials
        from dlt.common.storages.configuration import FilesystemConfiguration

        # 鍵は渡さない。dlt は既定チェーンから解決した認証情報を見つけると
        # DuckDB 側に PROVIDER credential_chain / REFRESH auto の secret を書くので、
        # 15 分で切れる一時認証情報でも取り直される (値を渡すと凍結される)。
        # チェーンが辿るプロファイルは queria run が AWS_CONFIG_FILE と
        # AWS_PROFILE で指す。実測: secret の provider=credential_chain
        storage = FilesystemConfiguration(
            bucket_url=data_url,
            credentials=AwsCredentials(
                endpoint_url=os.environ.get("QUERIA_S3_ENDPOINT"),
                region_name=os.environ.get("QUERIA_S3_REGION", "auto"),
                s3_url_style="path",
            ),
        )

    credentials = DuckLakeCredentials(
        # dlt 1.18+ では ATTACH エイリアスを ducklake_name から導出する。
        # dbt profiles.yml の alias: e_stat と一致させる。
        ducklake_name="e_stat",
        catalog=catalog_url,
        storage=storage,
    )

    # ロード時の DuckDB メモリを境界化する。
    # cpi (約1350万行) のような大規模テーブルは、行ごとに複製されるメタデータ
    # struct (tab/cat01/area/time/stat_inf) のため初回フルロードのメモリが膨らみ、
    # DuckDB が自前の memory_limit に達して OutOfMemoryException を投げる
    # (GitHub ランナーで約12.4GiB)。
    #   - preserve_insertion_order=false: 挿入順保持のための全行バッファリングを
    #     やめ、ストリーミング挿入でピークメモリを下げる (DuckDB の INSERT OOM
    #     対策として公式に推奨)。
    #   - temp_directory: メモリ上限に達した演算子をディスクへスピルさせる
    #     (ducklake は in-memory DuckDB 接続のため明示しないとスピルできない)。
    spill_dir = Path(tempfile.gettempdir()) / "duckdb-estat-spill"
    spill_dir.mkdir(parents=True, exist_ok=True)
    credentials.global_config = {
        "preserve_insertion_order": False,
        "temp_directory": str(spill_dir),
    }

    return dlt.pipeline(
        pipeline_name="estat",
        destination=ducklake(credentials=credentials, override_data_path=True),
        dataset_name=SOURCE_SCHEMA,
    )
