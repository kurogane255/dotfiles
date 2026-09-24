#!/bin/bash
# 指定した pane の出力を pipe-pane でログファイルに記録する
# 使い方: pipe-log.sh <pane-target> <logfile>
TARGET="$1"
LOGFILE="$2"
# セッションごとに専用ソケット (tmux -L <名前>) を使っているため、外から呼ぶときは
# ソケットを渡さないと既定のサーバーに向かって無言で失敗する。tmux 内のフックから
# 実行される場合は $TMUX で解決されるので、その場合は何も足さない。
SOCKET="${3:-}"
if [ -n "$SOCKET" ]; then
  TMUX_ARGS=(-L "$SOCKET")
else
  TMUX_ARGS=()
fi

mkdir -p "$(dirname "$LOGFILE")"

# pipe-pane のコマンド文字列は strftime(3) で解釈されるため、
# pane_id 等に含まれる % がエスケープされないと日時指定子として壊れる。
# %% にして strftime に通し、リテラルの % に戻す。
LOGFILE_ESCAPED="${LOGFILE//%/%%}"

# ANSIエスケープシーケンス(色・カーソル制御・OSC)を除去し、
# プログレスバー等の "\r" による上書きは改行として残しつつ、
# 通常の "\r\n" 改行はそのまま1行にまとめて書き込む
# $|=1 が無いと stdout がファイル向けブロックバッファ (4096 バイト) になり、
# 出力の少ない pane はいつまでもログに書き出されない。
STRIP='
    BEGIN { $|=1 }
    s/\x1B\[[0-9;?]*[a-zA-Z]//g;
    s/\x1B\][^\x07\x1B]*(\x07|\x1B\\\\)//g;
    s/\x1B[()][A-Za-z0-9]//g;
    s/\x1B[=>]//g;
    s/\r(?!\n)/\n/g;
    s/\r\n/\n/g;
'
tmux "${TMUX_ARGS[@]}" pipe-pane -o -t "$TARGET" "perl -pe '$STRIP' >> '$LOGFILE_ESCAPED'"
