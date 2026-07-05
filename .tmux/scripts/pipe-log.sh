#!/bin/bash
# 指定した pane の出力を pipe-pane でログファイルに記録する
# 使い方: pipe-log.sh <pane-target> <logfile>
TARGET="$1"
LOGFILE="$2"

mkdir -p "$(dirname "$LOGFILE")"

# pipe-pane のコマンド文字列は strftime(3) で解釈されるため、
# pane_id 等に含まれる % がエスケープされないと日時指定子として壊れる。
# %% にして strftime に通し、リテラルの % に戻す。
LOGFILE_ESCAPED="${LOGFILE//%/%%}"
tmux pipe-pane -o -t "$TARGET" "cat >> '$LOGFILE_ESCAPED'"
