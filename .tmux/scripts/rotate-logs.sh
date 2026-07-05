#!/bin/bash
# ~/tmux-logs/panes/ 以下の古いログを圧縮・削除する（root不要、cronから起動）
LOG_DIR="$HOME/tmux-logs/panes"
[ -d "$LOG_DIR" ] || exit 0

# 1日以上経過した未圧縮ログを圧縮
find "$LOG_DIR" -maxdepth 1 -name "*.log" -mtime +1 -exec gzip -f {} \;

# 14日以上経過した圧縮済みログは削除
find "$LOG_DIR" -maxdepth 1 -name "*.log.gz" -mtime +14 -delete
