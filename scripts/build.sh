#!/usr/bin/env bash
# 説明 (テーブルの tabledoc.yml) の無いテーブル (取り込んだままの _source と dbt の中間テーブル) は掲載しない
export FDL_UNDESCRIBED="${FDL_UNDESCRIBED:-hidden}"
exec "$(dirname "$0")/../shared/scripts/build-fdl.sh" "$@"
