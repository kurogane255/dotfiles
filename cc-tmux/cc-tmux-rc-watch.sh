#!/bin/bash
# cc-tmux の各セッションを見て、Remote Control が落ちているものだけ
# ユニットごと再起動する。
#
# 再接続 (/remote-control の打ち直し) では復帰しないことが実測で分かっている。
# 一度失敗したプロセスは precondition を掴んだまま戻らないので、
# プロセスを入れ替えるしかない。
#
# ただし再起動は会話とバックグラウンドのシェルを道連れにするため、
# 「作業中でないこと」を確認できたセッションだけに限る。
set -u
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

STATE_DIR="$HOME/.cache/cc-tmux-rc-watch"
COOLDOWN=1800          # 同じセッションを再起動する最短間隔 (秒)
NEED_STRIKES=2         # 連続で何回失敗を見たら再起動するか
DRY_RUN="${DRY_RUN:-0}"

mkdir -p "$STATE_DIR"

# 有効化されているインスタンス名を列挙する
units=$(find "$HOME/.config/systemd/user/default.target.wants" \
          -name 'cc-tmux@*.service' -printf '%f\n' 2>/dev/null \
        | sed 's/^cc-tmux@//; s/\.service$//')

for n in $units; do
  # tmux が居ないならここでは触らない (systemd 側の Restart に任せる)
  tmux -L "$n" has-session -t "$n" 2>/dev/null || continue

  pane=$(tmux -L "$n" capture-pane -p -t "$n" 2>/dev/null) || continue
  tailpart=$(printf '%s\n' "$pane" | tail -6)

  # 判定はステータス行の "/rc failed" だけを見る。
  # 画面に残る "Session creation failed" のバナーは復旧後も流れずに
  # 残るため、これを見ると誤検知する。
  case "$tailpart" in
    */rc\ failed*) failed=1 ;;
    *)             failed=0 ;;
  esac

  strike_file="$STATE_DIR/$n.strikes"
  if [ "$failed" = "0" ]; then
    rm -f "$strike_file"
    continue
  fi

  # --- 作業中なら手を出さない ---
  busy=""
  case "$pane" in
    *"esc to interrupt"*)      busy="応答生成中" ;;
    *"shell still running"*)   busy="シェル実行中" ;;
    *"Do you want"*)           busy="許可待ち" ;;
    *"❯ 1."*)                  busy="選択待ち" ;;
  esac
  if [ -n "$busy" ]; then
    echo "$n: /rc failed だが $busy のため見送り"
    continue
  fi

  # --- 連続失敗の回数を数える (一時的な断で暴発させない) ---
  strikes=$(( $(cat "$strike_file" 2>/dev/null || echo 0) + 1 ))
  echo "$strikes" > "$strike_file"
  if [ "$strikes" -lt "$NEED_STRIKES" ]; then
    echo "$n: /rc failed ($strikes/$NEED_STRIKES) 次回まで様子見"
    continue
  fi

  # --- 再起動の間隔を空ける ---
  last_file="$STATE_DIR/$n.last"
  now=$(date +%s)
  last=$(cat "$last_file" 2>/dev/null || echo 0)
  if [ $(( now - last )) -lt "$COOLDOWN" ]; then
    echo "$n: /rc failed だが $(( (COOLDOWN - (now - last)) / 60 ))分のクールダウン中"
    continue
  fi

  if [ "$DRY_RUN" = "1" ]; then
    echo "$n: [DRY RUN] cc-tmux@$n.service を再起動する"
    continue
  fi

  echo "$n: /rc failed が $strikes 回続いたので cc-tmux@$n.service を再起動する"
  systemctl --user restart "cc-tmux@$n.service"
  echo "$now" > "$last_file"
  rm -f "$strike_file"
  # 同時に張りに行かせない
  sleep 30
done
