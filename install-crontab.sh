#!/bin/bash
# ~/.tmux/scripts/rotate-logs.sh 用のcronエントリをユーザーcrontabに登録する(root不要)
set -e

SCRIPT_PATH="$HOME/.tmux/scripts/rotate-logs.sh"
CRON_LINE="0 4 * * * $SCRIPT_PATH"

if crontab -l 2>/dev/null | grep -Fq "$SCRIPT_PATH"; then
    echo "already registered: $SCRIPT_PATH"
    exit 0
fi

(crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
echo "registered: $CRON_LINE"
