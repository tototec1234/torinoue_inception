# セッションログ #0020

> 日付: 2026-04-12（セッション跨ぎ: 2026-04-11 夜〜04-12 未明）
> セッション種別: タスク 3-5（MariaDB + WordPress 2 コンテナテスト）
> 対応フェーズ: 3
> 開始: 約 2026-04-11 22:55（終了時刻と実作業時間 3h より逆算）
> 終了: 2026-04-12 01:55（ドライバーが Mac ホストで `date '+%Y-%m-%d %H:%M'` で取得）
> 実作業時間: 3.0h（ドライバー申告）
> 計画時間: 2h（`phase_plan.md` タスク 3-5）※実績は試行錯誤を含む

## このセッションで完了したこと

- **タスク 3-5 完了**: Vagrant 上の Docker で **ユーザ定義ネットワーク**（`inception-test-net`）に **MariaDB** と **WordPress** を載せ、`docker run` の環境変数で DB 名・ユーザー・パスワードを整合させて結線テストを実施
- **`mariadb-client`**: `entrypoint.sh` の `mariadb-admin ping` 用に Dockerfile で `apk add mariadb-client` を追加（セッション #0019 で「3-5 で実験してから」とした方針どおり）
- **到達確認**: `docker logs` で `Success: WordPress installed successfully.` / `Success: Created user 2.`、`wp --allow-root --path=/var/www/html db check` で **全テーブル OK**（DB 接続・スキーマ確認）
- **実行時 DNS**: コンテナ内から `api.wordpress.org` へ到達するため `docker run --dns 8.8.8.8` を使用
- **PHP メモリ**: `wp core download` の ZIP 展開で 128MB 上限に当たったため、`conf/docker-php-memlimit.ini`（`memory_limit = 256M`）を `COPY` する対応
- **entrypoint の処理順**: `wp config create` を `wp core download` より前に実行していたため WP-CLI が「WordPress ではない」と出る／`wp-config.php` が後段で欠ける問題があった。**コア取得 → `wp config create` → `wp core install`** の順に変更
- **`www.conf`**: PHP-FPM の INI パーサが `#` コメント行で失敗したため、**コメントを `;` にする／最小構成にする**方向で整理（詳細は Spike 記録）

## Spike記録

### Spike: 環境変数 typo・欠落による失敗パターン

**背景:** 手動 `docker run` で typo（`MARIADB_DATABESE`、`WP_ADMIN_PADDWORD`、`MARIADB_USER=wpuse`）や **`MARIADB_PASSWORD` 未設定**があり、MariaDB init の SQL エラー（`ERROR 1064` near `''`）、`mariadb-admin` の **Segmentation fault**（`-p` だけになる）、WordPress 側の ping／`wp config create` 失敗などが発生した。

**解説:** `MARIADB_DATABASE` が空だと `CREATE DATABASE IF NOT EXISTS ;` となり構文エラー。`MARIADB_PASSWORD` が空だと `-p` の解釈が崩れ、クライアントが異常終了することがある。WordPress には **MariaDB 側と同一の `MARIADB_*` 三つ**を必ず渡す。

### Spike: デフォルト bridge とユーザ定義 bridge の DNS

**背景:** コンテナ名 `mariadb` で `mariadb-admin ping -h mariadb` が通らない。ネットワーク名の typo（`inceptiono-test-net`）で意図したネットワークに繋がらないケースもあった。

**解説:** コンテナ名による名前解決は **ユーザ定義 bridge** で期待どおり動くことが多い。`docker network connect inception-test-net <container>` または `--network` で統一する。

### Spike: `wp core download` と PHP `memory_limit`

**背景:** `cURL error 6` は実行時 DNS。解決後、`Allowed memory size of 134217728 bytes exhausted` が `Extractor.php` で発生。

**解説:** Alpine の PHP 既定 128M では ZIP 展開が足りない場合がある。`conf.d` に `memory_limit` を置くなど CLI と共有する設定で対処。

## PoC記録

### PoC: タスク 3-5 合格基準（DB 接続）

**目的:** `wp-config.php` 経由で MariaDB に接続でき、WordPress テーブルが作成されていることを確認する。

**手順:** 2 コンテナ起動後、`docker exec wordpress wp --allow-root --path=/var/www/html db check`

**結果:** 全テーブル `OK`、`Success: Database checked.`

**判定:** **達成**（タスク 3-5 完了としてよい）

## 補足（運用上のメモ）

- **`sendmail: can't connect to remote host`**: コンテナに MTA が無いため。インストール自体は成功しており、本タスクでは問題としなかった
- **計画時間 2h に対し実績 3h**: 手動 `docker run` の typo 切り分け、DNS・メモリ・entrypoint 順・FPM 設定の順に潰したため

## 次のセッションでやること

- **タスク 3-6**: 3 コンテナ統合テスト（NGINX 追加）、ブラウザ／`https` での確認（`phase_plan.md` 参照）
- または **フェーズ 4**（docker-compose、secrets、healthcheck）へ進むかは `phase_plan.md` とドライバー判断

## 新しいチャット開始時のコピペ用指示文

```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール）
- session_logs/ 内の最新セッションログ（最も番号が大きいファイル）

今日やること: タスク 3-7　コンテナ統合テスト（NGINX追加）
環境: 自宅 M2 Mac + Vagrant

セッション開始時刻の記録（ターミナルで実行し、結果をチャットに貼る）:
date '+%Y-%m-%d %H:%M'
```
