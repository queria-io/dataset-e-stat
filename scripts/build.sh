#!/usr/bin/env bash
# 記述 (*.table.yml) の無いテーブル (取り込んだままの _source と dbt の中間テーブル) は掲載しない
export FDL_UNDESCRIBED="${FDL_UNDESCRIBED:-unlisted}"
exec "$(dirname "$0")/../shared/scripts/build-fdl.sh" "$@"
