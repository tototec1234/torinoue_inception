# セッションログ #0016

> 日付: 2026-04-10
> セッション種別: 既存コンテナ（MariaDB, NGINX）の iMac 環境動作確認
> 対応フェーズ: フェーズ7 先行検証（校舎環境移植の部分テスト）
> 環境: 42Tokyo 校舎 旧PC（iMac + Ubuntu + VirtualBox）
> 開始: 2026-04-10 05:05
> 終了: 2026-04-10 05:45
> 実作業時間: 1h
> 計画時間: （フェーズ7 の一部を前倒し実施）

---

## このセッションで完了したこと

- MariaDB コンテナ（Alpine 3.21）の x86_64 環境でのビルド・単体テスト合格
- NGINX コンテナ（Alpine 3.21）の x86_64 環境でのビルド・TLS 接続テスト合格
- MariaDB `entrypoint.sh` のバグ修正: 匿名ユーザー削除 + test DB 削除を追加

---

## MariaDB テスト結果

| テスト項目 | 結果 |
|-----------|------|
| `docker build` | OK（Alpine 3.21 x86_64） |
| コンテナ起動・初期化フロー | OK（mariadb-install-db → 一時起動 → SQL → shutdown → 本番起動） |
| `mariadb-admin ping` | `mysqld is alive` |
| `wpuser` ログイン | **初回失敗** → 匿名ユーザー修正後 OK |
| MariaDB バージョン | 11.4.8-MariaDB |

### 匿名ユーザー問題（バグ修正）

**問題**: `mariadb-install-db` がデフォルトで作成する匿名ユーザー（`''@'localhost'`）が、`wpuser@%` より先にマッチしてしまい、`wpuser` の認証が `Access denied` になった。

**原因**: MariaDB のユーザーマッチングは Host の具体性が優先される。`localhost`（匿名）が `%`（wpuser）より具体的なため、匿名ユーザーが先にマッチ。

**修正**: `entrypoint.sh` の SQL ブロックに以下を追加:
```sql
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
```

**一次資料**: https://mariadb.com/kb/en/mariadb-install-db/#user-accounts-created-by-default

---

## NGINX テスト結果

| テスト項目 | 結果 |
|-----------|------|
| `docker build` | OK（Alpine 3.21 x86_64） |
| TLS バージョン | TLSv1.3 |
| 暗号スイート | TLS_AES_256_GCM_SHA384 / x25519 / RSASSA-PSS |
| 証明書 | C=JP; ST=Tokyo; L=Minatoku; O=42Tokyo; OU=42cursus; CN=torinoue |
| 443 リッスン | OK |

---

## Spike記録

### Spike: MariaDB 匿名ユーザーによる認証横取り

- コマンド:
```bash
docker exec mariadb-test mariadb -u wpuser -pwppassword wordpress -e "SHOW TABLES;"
# → ERROR 1045 (28000): Access denied for user 'wpuser'@'localhost' (using password: YES)

docker exec mariadb-test mariadb -e "SELECT User, Host, plugin FROM mysql.user;"
# → 匿名ユーザー ''@'localhost' と ''@'<container_id>' が存在
```

- 結果: `wpuser@%` が存在するにもかかわらず、匿名ユーザー `''@'localhost'` が先にマッチして認証失敗
- 解説: MariaDB はユーザーマッチング時に Host の具体性を優先する。`localhost` は `%` より具体的なため、匿名ユーザーが `wpuser` より先にマッチする。`mariadb-install-db` はデフォルトで匿名ユーザーを作成するため、初期化 SQL で明示的に削除する必要がある。M2 Mac 環境では発見されなかった問題が iMac 環境のテストで発覚した（M2 Mac ではこのテストを実施していなかった可能性）。レビューで「なぜ匿名ユーザーを削除するのか」と聞かれたときの説明ポイント。

---

### Spike: VBoxManage controlvm savestate が機能しない

- コマンド:
```bash
# 方法1: list runningvms から取得（失敗）
VM_NAME=$(VBoxManage list runningvms | head -1 | sed 's/"\(.*\)".*/\1/')
VBoxManage controlvm "$VM_NAME" savestate
# → 0%...100% と表示されるが、VM は停止しない（VM_NAME が空で空振り）

# 方法2: VM名を直接指定（失敗）
VBoxManage controlvm vm_default_1775761662708_15919 savestate
# → Machine 'vm_default_1775761662708_15919' is not currently running.

# 方法3: UUID で直接指定（失敗）
VBoxManage controlvm 293d1d5f-2f8e-4c56-a35b-6904d9df3a9a savestate
# → Machine '293d1d5f-...' is not currently running.

# 検証: VBoxHeadless は動いている
ps aux | grep VBoxHeadless
# → PID 319734 で vm_default_1775761662708_15919 が running

# 解決策: ゲスト内からシャットダウン
sudo shutdown -h now
# → Connection closed, VBoxHeadless プロセス消滅
```

- 結果: `VBoxManage` のサブコマンド（`list runningvms`, `controlvm savestate`）がすべて VM を認識しない
- 解説: Vagrant AppImage のライブラリ汚染により、`VBoxManage` が VBoxHeadless プロセスと正しく通信できない。VM 自体は正常に動作しているが、管理コマンドからは「存在しない」「running ではない」と認識される。唯一確実な停止方法は、ゲスト OS 内部から `sudo shutdown -h now` を実行すること。`savestate`（状態保存）は使えないため、次回起動時は cold boot になる。

---

## 方針決定の記録

### 次のステップの選択: WordPress 精読（3-1）の続き vs Vagrantfile 改修

**選択肢A（採択）: 自宅 M2 Mac で 3-1（WordPress 精読）の続き**
- フェーズ3 は課題のコア成果物（WordPress コンテナ）
- 残り ~50h に対して、フェーズ3〜8 で約 64h 分のタスクが残っている
- クリティカルパス上にある（WordPress が動かないと提出できない）

**選択肢B（不採択）: 校舎旧PC で Vagrantfile 改修（両環境対応）**
- `vagrant up` 一発起動は評価時の要件だが、根本原因は Vagrant AppImage のライブラリ汚染
- Vagrantfile の改修では解決しない可能性が高い
- phase_plan ではフェーズ7（校舎環境移植: 9h）で対応予定

**判断理由**: 手動ワークアラウンドが確立済みで校舎での開発・テストは可能。残り時間のリスクを考慮し、コア成果物の完成を優先する。Vagrant の根本修正はフェーズ7でまとめて対応する。

---

## 現在のファイル状態

| ファイル | 変更内容 |
|---------|---------|
| `srcs/requirements/mariadb/tools/entrypoint.sh` | 匿名ユーザー削除 + test DB 削除の SQL を追加 |

---

## 校舎旧PC（iMac）運用リファレンス

### VM 起動手順

```bash
# 1. VM起動
VM_NAME=$(VBoxManage list vms | head -1 | sed 's/"\(.*\)".*/\1/')
VBoxManage startvm "$VM_NAME" --type headless
sleep 15
ssh -p 2222 vagrant@127.0.0.1   # パスワード: vagrant

# 2. ゲスト内セットアップ（起動ごとに必要）
sudo modprobe vboxsf
sudo mkdir -p /vagrant
sudo mount -t vboxsf vagrant /vagrant
```

### コンテナテスト後の後片付け

```bash
# ゲスト内: テスト用コンテナとネットワークの削除
docker stop mariadb-test nginx-test wordpress 2>/dev/null
docker rm mariadb-test nginx-test wordpress 2>/dev/null
docker network rm inception-test-net 2>/dev/null
```

### VM 停止手順

**注意**: `VBoxManage controlvm savestate` はライブラリ汚染で機能しない。
`VBoxManage list runningvms` が空を返すため、VM名を取得できず savestate が空振りする。
`VBoxManage controlvm <VM名> savestate` で直接指定しても `not currently running` エラーになる。

```bash
# ゲスト内からクリーンシャットダウン（これが唯一確実な方法）
sudo shutdown -h now

# ホスト側で VBoxHeadless プロセスが消えたことを確認
ps aux | grep VBoxHeadless
```

### ゾンビプロセス確認（習慣づける）

```bash
ps aux | grep VBoxHeadless
# 不要なプロセスがあれば: kill <PID>
```

### iMac 環境の現在の状態

| 項目 | 値 |
|------|-----|
| VM名 | `vm_default_1775761662708_15919` |
| VM保存先 | `/sgoinfre/torinoue/VirtualBox_VMs` |
| 共有フォルダ | `/home/torinoue/0409inception` → `/vagrant` |
| Docker | 29.4.0 / Compose v5.1.2 |
| SSH | `ssh -p 2222 vagrant@127.0.0.1` (pw: vagrant) |
| MariaDB イメージ | ビルド済み（`mariadb-test:latest`） |
| NGINX イメージ | ビルド済み（`nginx-test:latest`） |

---

## 次のセッションでやること

**フェーズ3: WordPress コンテナ再構築 — タスク 3-1（参考実装の WordPress 精読）の続き**

- 環境: 自宅 M2 Mac
- セッション開始時: `date '+%Y-%m-%d %H:%M'` を実行して開始時刻を記録

---

## 未解決事項

- Vagrant AppImage ライブラリ汚染の根本修正（`vagrant up` 一発起動）→ フェーズ7 で対応予定
- phase_plan.md の開発環境欄の更新（iMac 追加、Dell 削除）

---

## 新しいチャット開始時のコピペ用指示文

```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール）
- session_logs/0016_session_log_inception.md（最新セッションログ）

今日やること: タスク 3-1（参考実装の WordPress 精読）の続き
環境: 自宅 M2 Mac

セッション開始時刻の記録（ターミナルで実行し、結果をチャットに貼る）:
date '+%Y-%m-%d %H:%M'
```
