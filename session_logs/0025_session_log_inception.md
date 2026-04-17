# セッションログ #0025

> 日付: 2026-04-16〜2026-04-18
> セッション種別: タスク 0-3（校舎VirtualBox環境セットアップ＋結合テスト）
> 対応フェーズ: 0
> 開始: 2026-04-16 10:00（ドライバー申告）
> 終了: 2026-04-18 01:30（ドライバー申告）
> 実作業時間: 8.0h（ドライバー申告。0.5h 切り上げ）
> 計画時間: 12h（`inception_progress_snapshot.md` B4 タスク 0-3）

## このセッションで完了したこと

- **タスク 0-3 着手**: 校舎 VirtualBox 環境（sudo 権限なし）で Inception 課題の結合テストを実施
  - VirtualBox VM を `VBoxManage` コマンドで作成・設定・起動（`0417Inception_vm`、Ubuntu 22.04、メモリ 2048MB、CPU 2）
  - NAT ポートフォワーディング設定（SSH: ホスト 3322 → ゲスト 22、HTTPS: ホスト 8443 → ゲスト 443）
  - 共有フォルダ設定（ホスト `torinoue_inception` → ゲスト `/media/sf_inception`、`--automount`）
  - VM 内に Docker CE 29.x + Docker Compose v5.x をインストール
  - `docker compose up --build` で 3 コンテナ（MariaDB, WordPress, NGINX）を起動
  - VM 内 `curl -k https://localhost/` で WordPress ページ応答確認（HTML 取得成功）
  - `docker exec wordpress wp --allow-root --path=/var/www/html db check` で全テーブル OK
  - ホスト側からポートフォワーディング経由で TLS 証明書確認（`NET::ERR_CERT_AUTHORITY_INVALID` = 自己署名証明書として想定どおり）
- **ドキュメント作成**:
  - `dev_docs/vm_setup_manual.md` — VirtualBox VM 作成・SSH 接続マニュアル（校舎環境 / Vagrant 不使用）
  - `dev_docs/vm_docker_setup_manual.md` — VM 内 Docker 環境セットアップマニュアル
- **`srcs/vm/init.sh` のタイポ修正**: `toruinoue` → `torinoue` に統一

## Spike記録

### Spike: VBoxManage による VM 操作の一連フロー（校舎環境・sudo 権限なし）

**背景:** 校舎環境では Vagrant が使えない（AppImage 不可、sudo なし）ため、`VBoxManage` コマンドで直接 VM を操作する必要がある。

**コマンドフロー:**

```bash
# --- 状態確認 ---
VBoxManage list vms                            # 登録済みVM一覧
VBoxManage list runningvms                     # 起動中VM一覧
VBoxManage showvminfo "0417Inception_vm" | grep State  # 個別VMの状態

# --- 起動 ---
VBoxManage startvm "0417Inception_vm" --type headless  # ヘッドレス起動

# --- SSH接続（ポートフォワーディング経由）---
ssh -p 3322 torinoue@localhost

# --- ネットワーク・ポートフォワーディング確認 ---
VBoxManage showvminfo "0417Inception_vm" | grep -i "nic\|rule\|forward"
ss -tlnp | grep 3322                          # ホスト側のポートリッスン確認

# --- ポートフォワーディング追加（VM停止中）---
VBoxManage modifyvm "0417Inception_vm" --natpf1 "ssh,tcp,,3322,,22"
VBoxManage modifyvm "0417Inception_vm" --natpf1 "https,tcp,,8443,,443"

# --- ポートフォワーディング追加（VM起動中）---
VBoxManage controlvm "0417Inception_vm" natpf1 delete ssh
VBoxManage controlvm "0417Inception_vm" natpf1 "ssh,tcp,,3322,,22"

# --- 停止 ---
VBoxManage controlvm "0417Inception_vm" poweroff

# --- 共有フォルダ追加（VM停止中のみ）---
VBoxManage sharedfolder add "0417Inception_vm" --name "inception" \
  --hostpath "/home/torinoue/torinoue_inception" --automount
```

**解説:** Vagrant は `vagrant up/halt/ssh` で上記を抽象化しているが、校舎環境では VBoxManage を直接使う。ポートフォワーディング（`--natpf1`）によりホストの特定ポートからゲスト内サービスにアクセス可能。ホスト側に sudo 権限がなくても、1024 以上のポートであれば制限なく使用できる。`sharedfolder add` は VM 停止中のみ実行可能（VirtualBox 7.0.26 の `controlvm` には `sharedfolder` サブコマンドが存在しない）。

### Spike: 校舎環境での `/etc/hosts` 編集不可とブラウザアクセスの制約

**背景:** 校舎のホストマシンで `sudo` 権限がないため、`/etc/hosts` にドメインを追加できない。`https://127.0.0.1:8443/` でアクセスした場合、TLS 証明書のエラーページは表示される（＝ NGINX は応答している）が、証明書承認後に WordPress が `siteurl` に基づきリダイレクトする。

**確認コマンド:**

```bash
# sudo不可の確認
sudo nano /etc/hosts
# → torinoue is not in the sudoers file. This incident will be reported.

# ホスト側からのリダイレクト先確認
curl -k -v https://127.0.0.1:8443/ 2>&1 | grep -i location
# → Location: https://127.0.0.1/
```

**解説:** ポートフォワーディング（8443→443）を使うと、NGINX/WordPress のリダイレクト先がデフォルトポート（443）になる。ホスト側の 443 番ポートには何もリッスンしていないため `ERR_CONNECTION_REFUSED` になる。VM 内（`curl -k https://localhost/`）では 443 番で直接アクセスするためこの問題は発生しない。評価時は評価者が `/etc/hosts` を設定し VM 内から直接アクセスするため問題にならない。

## PoC記録

### PoC: 校舎 VirtualBox 環境での 3 コンテナ結合テスト

**目的:** Vagrant なしの校舎 VirtualBox 環境で、Inception 課題の 3 コンテナ（MariaDB + WordPress + NGINX）が正しく動作することを確認する。

**手順:**

1. `VBoxManage` で VM を作成・起動（`0417Inception_vm`、Ubuntu 22.04）
2. VM 内に Docker CE + Docker Compose をインストール（`dev_docs/vm_docker_setup_manual.md` の手順）
3. 共有フォルダ `/media/sf_inception/srcs` で `docker compose up --build`
4. VM 内 `curl -k https://localhost/` で応答確認
5. `docker exec wordpress wp --allow-root --path=/var/www/html db check` で DB 確認

**結果:**

- WordPress ページの HTML が正常に返却された
- `Success: Created user 2.`（2 ユーザー作成成功）
- 全テーブル `OK`、`Success: Database checked.`

**判定:** **達成**（校舎 VirtualBox 環境での結合テスト成功。ブラウザ表示は `/etc/hosts` 制約のため VM 内確認のみ）

## 現在のファイル状態

- **新規作成:** `dev_docs/vm_setup_manual.md`、`dev_docs/vm_docker_setup_manual.md`
- **修正:** `srcs/vm/init.sh`（`toruinoue` → `torinoue` タイポ修正）

## 次のセッションでやること

- **タスク 4-2**（`docker-compose.yml` 完成）— `session_logs/0024_session_log_inception.md` の「次のセッション」に記載のとおり
- セッション開始時: `date '+%Y-%m-%d %H:%M'` を実行して開始時刻を記録

## 未解決事項

- ホストブラウザからのアクセス: `/etc/hosts` 編集不可のため、ポートフォワーディング経由のブラウザ確認は WordPress リダイレクト問題で不可。VM 内からの確認は成功済み。評価時は評価者が環境を設定
- 校舎環境では Vagrant が使えない（AppImage も不可）ため、VBoxManage 直接操作を採用。手順は `dev_docs/vm_setup_manual.md` に文書化済み
- タスク 0-3 残作業（計画 12h − 実動 8h = 残り 4h 相当）: 一時的に NGINX の設定を変更して校舎のブラウザからブログにアクセスするテスト

## 新しいチャット開始時のコピペ用指示文

```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール・学習論点・完了済み）
- dev_docs/inception_progress_snapshot.md（進捗数値・タスク表・クイズ単独）
- session_logs/ 内の最新セッションログ（最も番号が大きいファイル）

今日やること: タスク 4-2（docker-compose.yml）
環境: 自宅 M2 Mac + Vagrant

セッション開始時刻の記録（ターミナルで実行し、結果をチャットに貼る）:
date '+%Y-%m-%d %H:%M'
```
