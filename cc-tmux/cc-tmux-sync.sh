#!/usr/bin/env bash
# ~/.config/cc-tmux/sessions に書いた一覧へ、有効な cc-tmux@ インスタンスを合わせる。
#
# このファイルだけを編集すれば enable / disable / start / stop は全部ここが面倒を見る。
# 書式は 1 行 1 セッション名。空行と # 以降は無視する。
#
# **一覧はこのファイルが正。** 手で systemctl --user enable しても次の sync で巻き戻る。
#
#   反映:   systemctl --user start cc-tmux-sync      (cc-tmux-sync.path が自動で叩く)
#   確認:   DRY_RUN=1 ~/cc-tmux-sync.sh
set -u

# sort と comm の照合順を一致させる。ja_JP.UTF-8 のままだと sort が大文字と
# ハイフンを無視して並べ、comm がそれを「未整列」と見て取りこぼす。
export LC_ALL=C

CONF="${CC_TMUX_CONF:-$HOME/.config/cc-tmux/sessions}"
WANTS="$HOME/.config/systemd/user/default.target.wants"
DRY_RUN="${DRY_RUN:-0}"

run() {
  if [ "$DRY_RUN" = 1 ]; then
    echo "DRY: $*"
  else
    "$@"
  fi
}

if [ ! -f "$CONF" ]; then
  echo "cc-tmux-sync: $CONF が無い。何もしない。" >&2
  exit 0
fi

# 欲しい一覧
desired=$(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$CONF" | grep -v '^$' | sort -u)

# いま有効になっている一覧
current=$(find "$WANTS" -name 'cc-tmux@*.service' -printf '%f\n' 2>/dev/null \
          | sed -e 's/^cc-tmux@//' -e 's/\.service$//' | sort -u)

# 一覧から消えたものを止める
while IFS= read -r s; do
  [ -n "$s" ] || continue
  echo "disable cc-tmux@$s"
  run systemctl --user disable --now "cc-tmux@$s.service"
done < <(comm -13 <(printf '%s\n' "$desired") <(printf '%s\n' "$current"))

# 一覧に増えたものを有効化する
while IFS= read -r s; do
  [ -n "$s" ] || continue
  echo "enable cc-tmux@$s"
  run systemctl --user enable "cc-tmux@$s.service"
done < <(comm -23 <(printf '%s\n' "$desired") <(printf '%s\n' "$current"))

# 有効なのに動いていないものを起動する。
# boot 中に自分自身を待って詰まらないよう --no-block で投げる。
while IFS= read -r s; do
  [ -n "$s" ] || continue
  if [ ! -d "$HOME/$s" ]; then
    # cc-tmux@.service の ConditionPathIsDirectory と同じ条件。
    # ここで黙って飛ばすと「有効なのに上がらない」理由が分からなくなる。
    echo "警告: ~/$s が無いので cc-tmux@$s は起動しない" >&2
    continue
  fi
  if ! systemctl --user is-active --quiet "cc-tmux@$s.service"; then
    echo "start cc-tmux@$s"
    run systemctl --user start --no-block "cc-tmux@$s.service"
  fi
done < <(printf '%s\n' "$desired")
