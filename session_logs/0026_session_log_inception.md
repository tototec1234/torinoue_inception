# セッションログ #0026

> 日付: 2026-04-18
> セッション種別: タスク 4-2（docker-compose.yml 完成）
> 対応フェーズ: 4
> 開始: 2026-04-18 22:38
> 終了: 2026-04-19 00:53
> 実作業時間: 2.0h（ドライバー指定。2h15m → 切り下げ）
> 計画時間: 3h（`inception_progress_snapshot.md` B4 タスク 4-2）

## このセッションで完了したこと

- **タスク 4-2 完了**: `srcs/docker-compose.yml` を課題要件を満たす形に完成
  - 3サービス定義（mariadb, wordpress, nginx）
  - `container_name` を各サービスに設定（課題書「各 Docker イメージは対応するサービスと同じ名前」）
  - `networks:` セクション定義（`torinoue_network`, `driver: bridge`）
  - `volumes:` に `driver_opts`（`device`, `o: bind`, `type: none`）で `/home/torinoue/data/` にマッピング
  - `restart: unless-stopped`（全サービス）
  - `depends_on` で起動順制御（mariadb → wordpress → nginx）
  - NGINX のみ `ports: "443:443"`
  - NGINX に `wordpress_data:/var/www/html` ボリュームを追加（静的ファイル配信のため）
  - `environment:` セクションの重複を削除（`.env` の `env_file:` のみに統一）
  - `dns: 8.8.8.8` を除去（Docker 内部 DNS で十分）
  - nginx の `depends_on` から不要な `mariadb` を除去
- **校舎 VirtualBox 環境で動作確認**:
  - `docker compose up -d` で 3 コンテナ正常起動
  - `curl -k https://localhost/` で WordPress ページ応答確認
  - `wp --allow-root --path=/var/www/html post list` で投稿一覧確認
  - ブラウザで WordPress 管理画面・投稿作成が正常動作

## Spike記録

### Spike: `restart: unless-stopped` が `docker kill` 後に自動再起動しない現象

**背景:** 課題書の「クラッシュ時に自動で再起動」要件を検証するため、`docker kill` でコンテナを強制終了して自動再起動を確認した。

**コマンド:**

```bash
# restart ポリシー確認
docker inspect wordpress --format '{{json .HostConfig.RestartPolicy}}'
# → {"Name":"unless-stopped","MaximumRetryCount":0}

# コンテナ強制終了
docker compose down && docker compose up -d
sleep 20
docker kill wordpress
sleep 10
docker ps -a
# → wordpress: Exited (137) — 再起動せず

# イベントログ確認
docker events --since 5m --filter container=wordpress
# → kill → die イベントのみ。start イベントなし
```

**結果:** `unless-stopped` ポリシーが設定されているにもかかわらず、`docker kill` 後にコンテナが自動再起動しなかった。`docker start wordpress` で手動起動は可能。

**解説:** Docker Engine 29.x + Docker Compose v5.x の組み合わせ、または VirtualBox 共有フォルダ上での Docker 動作に起因する可能性がある。タスク 4-7（統合テスト）および フェーズ 5（エッジケーステスト）で再検証予定。ポリシー設定自体は正しい（`docker inspect` で確認済み）。

### Spike: wp-cli コマンドによるコンテナ内 WordPress 操作

**コマンド:**

```bash
docker exec wordpress wp --allow-root --path=/var/www/html post list
```

| 部分 | 意味 |
|------|------|
| `docker exec wordpress` | 稼働中の `wordpress` コンテナ内でコマンドを実行 |
| `wp` | wp-cli（WordPress コマンドラインツール） |
| `--allow-root` | root ユーザーでの実行を許可（デフォルトでは安全のため拒否） |
| `--path=/var/www/html` | WordPress のインストールディレクトリを指定 |
| `post list` | 投稿一覧を表示するサブコマンド |

**結果:**

```
ID  post_title    post_name    post_date            post_status
9   h             -            2026-04-18 15:18:07  draft
1   Hello world!  hello-world  2026-04-18 14:37:37  publish
```

**一次資料:** [wp-cli.org — wp post list](https://developer.wordpress.org/cli/commands/post/list/)

### Spike: NGINX に WordPress ボリュームが必要な理由

**背景:** NGINX コンテナに `wordpress_data` ボリュームをマウントしないと、ブラウザでページが表示されるが CSS/JS が適用されず崩れる（白画面やスタイルなしの箇条書き表示になる）。

**原因:** `nginx.conf` の動作:
1. `.php` リクエスト → `fastcgi_pass wordpress:9000` → WordPress コンテナが処理 → **動く**
2. 静的ファイル（`.css`, `.js`, 画像）→ NGINX 自身がファイルシステムから配信 → ボリュームがないと **404**

**解決:** `docker-compose.yml` の nginx サービスに `wordpress_data:/var/www/html` を追加。

### Spike: `docker compose stop` vs `down` vs `down -v`

| コマンド | コンテナ | ネットワーク | ボリューム |
|---------|---------|------------|-----------|
| `stop` | 停止（残る） | 残る | 残る |
| `down` | 停止+削除 | 削除 | 残る |
| `down -v` | 停止+削除 | 削除 | 削除 |

`stop` → `up` の場合、Compose は設定変更があったコンテナのみ再作成し、変更がないコンテナはそのまま再起動する。ただし、コンテナ作成後に追加された `restart` ポリシー等は `down` → `up` で再作成しないと反映されない場合がある。

### Spike: `container_name` 未設定時のコンテナ名解決の罠

**背景:** `docker-compose.yml` に `container_name` を設定しない場合、Compose は `{プロジェクト名}-{サービス名}-{番号}` 形式の名前を自動生成する（例: `srcs-wordpress-1`）。以前の `docker run` テストで `--name wordpress` として作成した古いコンテナが残っていると、`docker exec wordpress` が停止中の古いコンテナを参照してしまう。

**解決:** `container_name: wordpress` を明示的に設定。課題書にも「各 Docker イメージは対応するサービスと同じ名前でなければならない」とある。

## PoC記録

（本セッションでは採用なし）

## 現在のファイル状態

- **修正:** `srcs/docker-compose.yml`（タスク 4-2 完成版）

## 次のセッションでやること

- **タスク 4-3**（secrets ディレクトリ＋ファイル作成）— `db_password.txt`, `db_root_password.txt`, `wp_admin_password.txt`
- セッション開始時: `date '+%Y-%m-%d %H:%M'` を実行して開始時刻を記録

## 未解決事項

- `restart: unless-stopped` が `docker kill` 後に自動再起動しない現象（タスク 4-7 / フェーズ 5 で再検証）
- `docker-compose.yml` のコメントアウトされたパスワード行は提出前に完全削除が必要

## 新しいチャット開始時のコピペ用指示文

```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール・学習論点・完了済み）
- dev_docs/inception_progress_snapshot.md（進捗数値・タスク表・クイズ単独）
- session_logs/ 内の最新セッションログ（最も番号が大きいファイル）

今日やること: タスク 4-3（secrets ディレクトリ＋ファイル作成）
環境: 自宅 M2 Mac + Vagrant

セッション開始時刻の記録（ターミナルで実行し、結果をチャットに貼る）:
date '+%Y-%m-%d %H:%M'
```
