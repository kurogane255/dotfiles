#!/bin/bash

# 1. 引数の入力チェック
if [ -z "$1" ]; then
    echo "❌ エラー: プロジェクト名を指定してください。"
    echo "   使い方: $0 <プロジェクト名>"
    exit 1
fi

NAME="$1"
TARGET_DIR="$HOME/$NAME"

# 2. ディレクトリの存在チェック
if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ エラー: ディレクトリ '$TARGET_DIR' が存在しません。"
    exit 1
fi

# 3. 【-dを追加】最初からバックグラウンド（裏）でtmuxを起動
#    -L で専用ソケットを使い、セッションごとに独立したtmuxサーバーを立てる。
#    共有サーバーだと1セッションを落としたとき全部が巻き添えになるため。
tmux -L "$NAME" new-session -d -s "$NAME" "cd '$TARGET_DIR' && claude --rc -n \"$NAME\""

echo "✅ セッション '$NAME' を裏で起動しました。"
echo "🔗 スマホから接続するか、手元で見る場合は 'tmux -L $NAME a -t $NAME' を実行してください。"

