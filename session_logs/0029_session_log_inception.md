# セッションログ #0029

> 日付: 2026-04-19
> セッション種別: タスク 4-5 + 4-6（各 entrypoint.sh を secrets 読み取り対応に修正 + .env 整理）
> 対応フェーズ: 4
> 開始: 2026-04-19 22:05
> 終了: 2026-04-19 23:30
> 実作業時間: 1.5h
> 計画時間: 3h（タスク 4-5: 2h + タスク 4-6: 1h）

## このセッションで完了したこと

- **タスク 4-5 完了**: MariaDB・WordPress 両方の `entrypoint.sh` を `/run/secrets/<name>` から `cat` で読み取るよう修正
  - MariaDB: `MARIADB_PASSWORD=$(cat /run/secrets/db_password | tr -d '\n')` を **if ブロック内**（SQL 実行前）に配置。初期化済みならパスワード不要のため冒頭ではなく使用箇所の直前に置く判断
  - WordPress: `MARIADB_PASSWORD` は **冒頭**（ping ループで毎回使うため）、`WP_ADMIN_PASSWORD` と `WP_USER_PASSWORD` は **`if ! wp core is-installed` ブロック内**（初回のみ使用）に配置
- **タスク 4-6 完了**: `.env` からパスワード関連のコメントアウト行を削除し、非機密値のみに整理
  - `WP_USER_PASSWORD`（editor ユーザー）も secrets に移行する判断 → `secrets/wp_editor_password.txt` 新規作成、`docker-compose.yml` に `wp_editor_password` secret 追加
- **動作確認**: `docker compose down -v && docker compose up --build --detach` → `curl -kI https://localhost:443` で HTTP 200 OK、ブラウザでも正常動作確認

## Spike記録

### Spike 1: `--build` なしの `docker compose up` で entrypoint.sh 変更が反映されない問題（Segmentation fault）

**コマンド:**

```bash
docker compose down -v
docker compose up --detach      # --build なし
docker logs wordpress
```

**結果:** `Segmentation fault (core dumped)` が繰り返し出力され、WordPress コンテナがクラッシュループに陥った。

**解説:** `entrypoint.sh` は Dockerfile の `COPY` でイメージに焼き込まれる。`docker compose up` は `--build` を指定しないと**既存イメージを再利用**する。つまりコンテナ内の `entrypoint.sh` は修正前のまま。修正前の entrypoint は `$MARIADB_PASSWORD` を環境変数から読むが、`.env` からパスワード行を削除済みのため空文字になり、`mariadb-admin ping -p`（パスワード空）で segfault が発生した。

| 操作 | リセットされるもの | 残るもの |
|------|-------------------|---------|
| `docker compose down` | コンテナ、ネットワーク | **ボリューム、イメージ** |
| `docker compose down -v` | コンテナ、ネットワーク、**ボリューム** | **イメージ** |
| `docker compose up --build` | — | イメージを**再ビルド** |

**教訓:** Dockerfile の `COPY` で取り込んだファイルを変更したら、必ず `--build` をつける。

### Spike 2: シェル変数の代入と環境変数の優先度

**コマンド:**（実行ではなく、entrypoint.sh 内の挙動の確認）

```sh
MARIADB_PASSWORD=$(cat /run/secrets/db_password | tr -d '\n')
```

**結果:** 同名の環境変数が `env_file` 経由で設定されていても、シェル変数の代入で上書きされる。

**解説:**
- `export` なしの代入 → **シェル変数**（同プロセス内で有効、子プロセスには渡らない）
- `export` ありの代入 → **環境変数を上書き**（子プロセスにも渡る）
- 今回は `entrypoint.sh` の同プロセス内で `$MARIADB_PASSWORD` を参照するので `export` なしで十分
- `.env` からパスワード行を削除済みなので実際には衝突しないが、仮に残っていても secrets の値が優先される設計

### Spike 3: secrets ファイルの改行有無の確認方法

**コマンド:**

```bash
wc -c ../secrets/db_password.txt
xxd ../secrets/db_password.txt | tail -1
```

**結果（改行なし）:**

```
10 ../secrets/db_password.txt
00000000: 7770 7061 7373 776f 7264                 wppassword
```

**結果（改行あり — vim で保存後）:**

```
11 ../secrets/db_password.txt
00000000: 7770 7061 7373 776f 7264 0a              wppassword.
```

**解説:** vim はデフォルトで保存時に末尾改行を追加する。`cat` で secret を読むと改行込みでパスワードに含まれ、認証失敗する。対策として `tr -d '\n'` を噛ませるのが安全。改行なしで作成するには `printf '%s' "password" > file.txt` を使う。`wc -c` のバイト数と文字数の差で改行の有無を判別できる。

### Spike 4: `docker compose down -v` でもホスト側データが残る理由

**コマンド:**

```bash
docker compose down -v
docker compose up --build --detach
docker logs wordpress
```

**結果:** `wp core download`、`wp config create`、`wp core install` の出力が一切なく、ping 成功後すぐに PHP-FPM が起動。

**解説:** `driver_opts` で `device: /home/torinoue/data/wordpress, o: bind, type: none` を設定している場合、`down -v` は Docker の named volume 定義を削除するが、**ホスト側ディレクトリの中身は残る**。そのため entrypoint.sh の各ガード（`if [ ! -f wp-settings.php ]` 等）がすべてスキップされ、初期化処理が実行されない。完全な再初期化には `sudo rm -rf /home/torinoue/data/wordpress/* /home/torinoue/data/mariadb/*` が必要。

## PoC記録

（本セッションでは採用なし）

## 現在のファイル状態

- **更新:** `srcs/requirements/mariadb/tools/entrypoint.sh`（secrets 読み取り追加）
- **更新:** `srcs/requirements/wordpress/tools/entrypoint.sh`（secrets 読み取り追加: db_password, wp_admin_password, wp_editor_password）
- **更新:** `srcs/docker-compose.yml`（wp_editor_password secret 追加）
- **更新:** `srcs/.env`（パスワード関連行を完全削除、非機密値のみ）
- **新規:** `secrets/wp_editor_password.txt`（editor ユーザーのパスワード）

## 次のセッションでやること

- **タスク 4-7**（統合テスト）— `docker compose down -v` + ホストデータ削除 → `docker compose up --build` → WP アクセス → コンテナ kill → 自動再起動 → ボリューム永続化確認
- セッション開始時: `date '+%Y-%m-%d %H:%M'` を実行して開始時刻を記録

## 未解決事項

- `docker-compose.yml` のコメントアウト行（学習用に残置中）は提出前に削除が必要
- `docker-compose copy.yml` は提出前に削除が必要
- `.env` 1行目のコメントに typo あり（`PADDWORD` → `PASSWORD`、`secerts` → `secrets`）— 提出前に修正
- `restart: unless-stopped` が `docker kill` 後に自動再起動しない現象（タスク 4-7 で再検証）

## 新しいチャット開始時のコピペ用指示文

```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール・学習論点・完了済み）
- dev_docs/inception_progress_snapshot.md（進捗数値・タスク表・クイズ単独）
- session_logs/ 内の最新セッションログ（最も番号が大きいファイル）

今日やること: タスク 4-7（統合テスト）
環境: 自宅 M2 Mac + Vagrant

セッション開始時刻の記録（ターミナルで実行し、結果をチャットに貼る）:
date '+%Y-%m-%d %H:%M'
```
