# セッションログ #0005

> 日付: 2026-03-25
> セッション種別: タスク1-4（MariaDB Dockerfile を Alpine 3.21 で新規作成）
> 対応フェーズ: 1
> 開始: 2026-03-25 02:32
> 終了: 2026-03-25 05:30
> 実作業時間: 2h
> 計画時間: 3h

---

## このセッションで完了したこと

- MariaDB Dockerfile を Alpine 3.21 で新規作成（Scaffolding 方式: AI = Navigator、学習者 = Driver）
- 参考実装との差別化ポイントを反映:
  - `mariadb-install-db` を Dockerfile から除外（entrypoint.sh で初期化ガード付き実行する設計）
  - 設定ファイルの配置先を `/etc/my.cnf.d/` に変更（Alpine の `!includedir` 構造を尊重）
  - `apk add --no-cache` でイメージサイズ最小化
  - ベースイメージを Alpine 3.21（penultimate stable）に設定
- ビルドテスト成功（`mariadb-test:task14`）
- イメージ内部の検証完了:
  - mariadbd 11.4.8-MariaDB (aarch64, Alpine)
  - `/run/mysqld` と `/var/lib/mysql` の所有権が `mysql:mysql`
  - `/etc/my.cnf.d/` に `mariadb-server.cnf`（デフォルト）と `my.cnf`（自分のもの）が配置
- セッション #0003 の未解決事項を2件解決:
  - `apk add mariadb` で `/var/lib/mysql` が自動作成されるか → **される**（空ディレクトリ、`mysql:mysql` 所有）
  - Alpine 3.21 で `/etc/my.cnf.d/mariadb-server.cnf` が存在するか → **存在する**（中に `skip-networking` あり）
- Docker volume マウントの「被さる（overlay）」概念を Spike で理解（Linux mount の仕組み）
- Dockerfile のビルドテストを PoC として実施・成功

---

## Spike記録

### Spike: `/etc/apk/` で volume マウントの「被さり」を実証

**コマンド:**
```bash
# マウントなし: イメージレイヤーのファイルが見える
docker run --rm alpine:3.21 sh -c "
  echo '--- no mount ---'
  ls /etc/apk/
"

# 空ディレクトリを被せる: 同じパスなのにファイルが見えなくなる
docker run --rm -v /tmp/test-apk:/etc/apk alpine:3.21 sh -c "
  echo '--- with mount ---'
  ls /etc/apk/
"
```

**結果:**
```
--- no mount ---
arch  keys  protected_paths.d  repositories  world
--- with mount ---
（何も表示されない）
```

**解説:**
- volume マウントは Linux カーネルの `mount` システムコールを使う。マウントポイント（`/etc/apk/`）に別のファイルシステム（ホスト側の `/tmp/test-apk`）を重ねる操作
- イメージレイヤーの元ファイルは**削除されていない**。マウントを外せば（volume なしで起動すれば）再び見える
- フロッピーディスクのマウントと同じ仕組み: 同じドライブ（パス）に別のメディア（volume）を挿すと中身が変わる
- **Inception での影響**: Dockerfile のビルド時に `/var/lib/mysql` を準備しても、Docker Compose で volume がマウントされると被さって見えなくなる。だから `mariadb-install-db` や `chown` は entrypoint.sh（volume マウント後に実行される）で行う必要がある

---

## PoC記録

### PoC: MariaDB Dockerfile (Alpine 3.21) ビルドテスト

**目的:** 自分で書いた Dockerfile が正しくビルドでき、想定通りの構成になるか検証する

**手順:**
```bash
# ダミーファイルを用意してビルド
echo '#!/bin/sh' > /vagrant/srcs/requirements/mariadb/tools/entrypoint.sh
echo '[mysqld]' > /vagrant/srcs/requirements/mariadb/conf/my.cnf
docker build --tag mariadb-test:task14 /vagrant/srcs/requirements/mariadb/

# イメージ内部を検証
docker run --rm --entrypoint sh mariadb-test:task14 -c "
mariadbd --version
ls -la /run/ | grep mysqld
ls -la /var/lib/ | grep mysql
ls /etc/my.cnf.d/
cat /etc/my.cnf.d/my.cnf
"
```

**結果:**
```
mariadbd  Ver 11.4.8-MariaDB for Linux on aarch64 (Alpine Linux)
drwxr-xr-x    2 mysql    mysql         4096 ... mysqld
drwxr-x---    2 mysql    mysql         4096 ... mysql
mariadb-server.cnf  my.cnf
[mysqld]
```

**判定:** 成功 — ビルド完了、mariadbd バージョン正常、ディレクトリ所有権 `mysql:mysql`、設定ファイル配置正常

---

## 現在のファイル状態

| ファイル | 変更内容 |
|---------|---------|
| `srcs/requirements/mariadb/Dockerfile` | Alpine 3.21 版に書き直し |
| `srcs/requirements/mariadb/tools/entrypoint.sh` | ダミー作成（ビルドテスト用、タスク1-6で本実装） |
| `srcs/requirements/mariadb/conf/my.cnf` | ダミー作成（ビルドテスト用、タスク1-5で本実装） |
| `session_logs/0005_session_log_inception.md` | 新規作成（このセッション） |

---

## 次のセッションでやること

タスク 1-5: my.cnf 作成（計画: 1h）
- `bind-address = 0.0.0.0`（コンテナ間TCP通信を許可）
- `port = 3306`
- デフォルトの `mariadb-server.cnf` にある `skip-networking` を上書き無効化する必要あり
- 配置先: `/etc/my.cnf.d/my.cnf`（Dockerfile で設定済み）

タスク 1-5 が短時間なら、タスク 1-6（entrypoint.sh 作成）もまとめて実施可

---

## 未解決事項

- 一時起動時の `--skip-networking` + unix_socket 認証でパスワードなしログイン可能か → タスク1-6で実機確認
- `mariadb-server.cnf` の `skip-networking` をどう上書きするか → タスク1-5で対処（`skip-networking = 0` or 別の方法）

---

## 新しいチャット開始時のコピペ用指示文

```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール）
- session_logs/ 内の最新セッションログ（最も番号が大きいファイル）

今日やること: タスク1-5 + 1-6（my.cnf 作成 + entrypoint.sh 作成）
```
