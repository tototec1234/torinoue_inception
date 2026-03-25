# セッションログ #0006

> 日付: 2026-03-25〜26
> セッション種別: タスク1-5 + 1-6 + 1-7（my.cnf 作成 + entrypoint.sh 作成 + 単体テスト）
> 対応フェーズ: 1
> 開始: 2026-03-25 21:23
> 終了: 2026-03-26 03:00
> 実作業時間: 5.0h
> 計画時間: 4h（1-5: 1h + 1-6: 2h + 1-7: 1h）

---

## このセッションで完了したこと

- タスク 1-5: `zaphod-mariadb.cnf` 作成（`conf/my.cnf` ダミーを置き換え）
  - `bind-address = 0.0.0.0`、`port = 3306`、`skip-networking = 0` を設定
  - ファイル名を `zaphod-` prefix にして `mariadb-server.cnf` より後に読まれるよう設計
  - Dockerfile を `zaphod-mariadb.cnf` コピーに更新
- タスク 1-6: `entrypoint.sh` 作成（本実装）
  - 初期化ガード + `mariadb-install-db` + 一時起動 + ping ループ（42回タイムアウト）+ SQL heredoc + シャットダウン + `exec mariadbd`
  - `.env.example` の変数名を `MYSQL_*` → `MARIADB_*` に統一
- タスク 1-7: 単体テスト実施・全項目合格
  - 5段階の初期化フローをログで確認
  - `mariadb-admin ping` / `SHOW DATABASES` / `SELECT user` で DB・ユーザー作成を確認
- 事後ミニクイズ実施 → `quizzes/0106_mariadb_entrypoint_post_quiz_inception.md` 作成

---

## Spike記録

### Spike: `zaphod-` 命名による設定ファイル読み込み順の制御

**コマンド:**
```bash
# コンテナ内で読み込み順を確認
docker run --rm --entrypoint sh mariadb-test:task14 -c "ls /etc/my.cnf.d/"
# → mariadb-server.cnf  zaphod-mariadb.cnf（アルファベット順）
```
**結果:**
```bash
mariadb-server.cnf  zaphod-mariadb.cnf
```
**解説:**

- MariaDB は `/etc/my.cnf` の `!includedir /etc/my.cnf.d` ディレクティブにより、`/etc/my.cnf.d/` 内のファイルをアルファベット順に読み込む
- 後に読まれた設定が優先されるため、`z` で始まるファイルは全てのパッケージ提供ファイルより後に読まれる
- `mariadb-server.cnf` には `skip-networking` が含まれており、これを `zaphod-mariadb.cnf` の `skip-networking = 0` で上書きする設計
- **Inception での影響:** コマンドライン引数（`--skip-networking`）は設定ファイルより優先されるため、一時起動時の `--skip-networking` は `zaphod-mariadb.cnf` の設定に関わらず TCP を無効にできる

### Spike: `[mysqld]` ヘッダー省略による設定無効化

**コマンド:**
```bash
# [mysqld] なしでビルド → コンテナ起動 → bind-address が反映されないことを確認
docker run -d --name mariadb-test-run \
  --env MARIADB_DATABASE=wordpress \
  --env MARIADB_USER=wpuser \
  --env MARIADB_PASSWORD=wppassword \
  mariadb-test:task15
docker logs mariadb-test-run 2>&1 | grep "port:"
# → port: 0 のまま（zaphod-mariadb.cnf が無視されている）
```

**結果:**
```
port: 0（設定が効いていない）→ [mysqld] ヘッダーを追記後は port: 3306 に変化
```

**解説:**
- MariaDB の設定ファイルはセクションヘッダー（`[mysqld]`、`[client]` 等）が必須
- ヘッダーがないと全ての設定行がパースされず無視される
- `bind-address = 0.0.0.0` の前に `[mysqld]` を書くことで初めてサーバー設定として認識される
- **レビューでの説明ポイント**: 「なぜ `[mysqld]` が必要か」と聞かれたらこの実験を根拠に説明できる

---

## PoC記録

### PoC: entrypoint.sh 全フロー動作確認（タスク1-7）

**目的:** 作成した entrypoint.sh が設計通り5段階の初期化フローを完遂するか検証する

**手順:**
```bash
docker run -d --name mariadb-test-run \
  --env MARIADB_DATABASE=wordpress \
  --env MARIADB_USER=wpuser \
  --env MARIADB_PASSWORD=wppassword \
  mariadb-test:task15
docker logs mariadb-test-run 2>&1
docker exec mariadb-test-run mariadb-admin ping
docker exec mariadb-test-run mariadb -u wpuser -pwppassword wordpress -e "SHOW DATABASES;"
docker exec mariadb-test-run mariadb -u root -e "SELECT user, host FROM mysql.user;"
```

**結果:**
```
# ログ（抜粋）
Installing MariaDB/MySQL system tables... OK   ← mariadb-install-db 完了
Starting MariaDB ... as process 55             ← 一時起動（PID 55、TCPなし port: 0）
mysqld is alive                                ← ping ループ成功
Starting MariaDB ... as process 1              ← 本番起動（PID 1、port: 3306）
Server socket created on IP: '0.0.0.0', port: '3306'  ← zaphod-mariadb.cnf の設定有効

# ping / SHOW DATABASES / SELECT user も全て期待通り
```

**判定:** 成功 — 全5段階の初期化フロー完了、DB・ユーザー作成確認、PID 1 での本番起動確認

---

## 現在のファイル状態

| ファイル | 変更内容 |
|---------|---------|
| `srcs/requirements/mariadb/conf/my.cnf` | 削除（ダミーから正式ファイルへ移行） |
| `srcs/requirements/mariadb/conf/zaphod-mariadb.cnf` | 新規作成（my.cnf の正式版、命名変更） |
| `srcs/requirements/mariadb/Dockerfile` | `zaphod-mariadb.cnf` コピーに更新 |
| `srcs/requirements/mariadb/tools/entrypoint.sh` | 本実装完成 |
| `srcs/.env.example` | `MYSQL_*` → `MARIADB_*` に変数名統一 |
| `quizzes/0106_mariadb_entrypoint_post_quiz_inception.md` | 新規作成（タスク1-6 事後クイズ） |

---

## 次のセッションでやること

タスク 1-8 相当: フェーズ1 事後クイズ → `quizzes/0100_alpine_mariadb_post_quiz_inception.md`
- タスク 1-5〜1-7 で確認した内容（設定ファイル読み込み順、ping ループ、exec 等）を中心に
- その後フェーズ 2（NGINX コンテナ構築）へ進む

---

## 未解決事項

- 匿名ユーザー（User=''）が `mariadb-install-db` によりデフォルト作成される → フェーズ4で secrets 対応時に削除予定
- Docker secrets 導入後は `entrypoint.sh` の `$MARIADB_PASSWORD` 読み取り方法を変更する必要あり（`/run/secrets/` から読む）

---

## 新しいチャット開始時のコピペ用指示文
```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール）
- session_logs/ 内の最新セッションログ（最も番号が大きいファイル）

今日やること: フェーズ1 事後クイズ（quizzes/0100_alpine_mariadb_post_quiz_inception.md）
```


