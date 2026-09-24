# cc-tmux

repo ごとに tmux セッションを立て、その中で Claude Code を常駐させる。
セッションは systemd の user unit が見張り、落ちたら起こし直す。

**どのセッションを立てるかは `~/.config/cc-tmux/sessions` の 1 ファイルだけで決まる。**
`systemctl --user enable` を手で打つ必要は無い。

## 構成

| ファイル | 役割 |
|---|---|
| `sessions.example` | 一覧の雛形。`~/.config/cc-tmux/sessions` に置く |
| `cc-tmux-sync.sh` | 一覧と有効なインスタンスの差分を取り、enable / disable / start / stop で合わせる |
| `cc-tmux.sh` | セッションを 1 つ作る。`cc-tmux@.service` から呼ばれる |
| `cc-tmux-rc-watch.sh` | Remote Control が落ちたインスタンスだけ再起動する |
| `systemd/cc-tmux@.service` | セッション本体のテンプレートユニット |
| `systemd/cc-tmux-sync.service` | 一覧を反映する oneshot |
| `systemd/cc-tmux-sync.path` | 一覧の変更を検知して sync を叩く |
| `systemd/cc-tmux-rc-watch.{service,timer}` | 5 分ごとに Remote Control を確認する |

テンプレートユニット (`cc-tmux@.service`) は意図的に残してある。
セッションごとに `Restart=always` と `StartLimitBurst=5` が独立して効くので、
1 つ落ちても他を巻き込まない。単一サービスに統合するとこれが失われる。

## 入れかた

```sh
install -m 755 cc-tmux.sh cc-tmux-rc-watch.sh cc-tmux-sync.sh ~/
install -m 644 systemd/* ~/.config/systemd/user/
mkdir -p ~/.config/cc-tmux
install -m 644 sessions.example ~/.config/cc-tmux/sessions   # 中身を編集する

loginctl enable-linger "$USER"        # ログアウトしても動かすため
systemctl --user daemon-reload
systemctl --user enable --now cc-tmux-sync.service cc-tmux-sync.path cc-tmux-rc-watch.timer
```

## 使いかた

`~/.config/cc-tmux/sessions` を編集するだけ。保存した時点で
`cc-tmux-sync.path` が拾って反映する。

```sh
DRY_RUN=1 ~/cc-tmux-sync.sh      # 何が起きるか先に見る
~/cc-tmux-sync.sh                # 手で反映する場合
```

セッション名は `~/<名前>` のディレクトリ名と一致させる。
`cc-tmux@.service` の `ConditionPathIsDirectory=%h/%i` があるため、
ディレクトリが無いインスタンスは有効化されても起動しない
(`cc-tmux-sync.sh` が警告を出す)。

## 複数ホストで使う場合

**同じ名前を 2 台で立てない。** 同じ repo に 2 つのセッションがぶら下がり、
両方が同じブランチを触ると衝突する。

移すときは、移動先で有効にする前に移動元の行を消す。
待機側は全行コメントアウトしておくと、そのまま引き取れる。

## 既知の引っかかり

- **`cc-tmux@.service` は `/home/kurogane` を直書きしている** (`Environment=PATH`
  と `ExecStart`)。別ユーザで使うなら書き換える
- **`cc-tmux-sync.sh` は `LC_ALL=C` を立てている。** 外すと ja_JP ロケールの
  `sort` が大文字とハイフンを無視して並べ、`comm` が「未整列」と見て取りこぼす
- **`pipe-log.sh` にはソケット指定が要る。** tmux の外から呼ぶときに `-L` を
  渡さないと既定サーバーに向かって無言で失敗する
