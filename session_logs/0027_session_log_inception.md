# セッションログ #0027

> 日付: 2026-04-19
> セッション種別: タスク 4-3（secrets ディレクトリ＋ファイル作成）
> 対応フェーズ: 4
> 開始: 2026-04-19 15:42
> 終了: 2026-04-19 16:43
> 実作業時間: 1.0h（61分 → 0.5h四捨五入）
> 計画時間: 1h（`inception_progress_snapshot.md` B4 タスク 4-3）

## このセッションで完了したこと

- **タスク 4-3 完了**: `secrets/` ディレクトリと 3 つの secrets ファイルを作成
  - `secrets/db_password.txt`（MariaDB ユーザーパスワード）
  - `secrets/db_root_password.txt`（MariaDB root パスワード）
  - `secrets/wp_admin_password.txt`（WordPress admin パスワード）
  - 全ファイル末尾改行なし（`echo -n` 使用、`wc -c` でバイト数確認済み）
  - `.gitignore` に `secrets/` が含まれていることを確認（git 追跡対象外）

## Spike記録

### Spike: Docker コンテナのホスト PID 確認

**コマンド:**

```bash
docker inspect --format '{{.State.Pid}}' mariadb
# → 1495

docker top mariadb
# → UID: systemd+, PID: 1495, CMD: mariadbd --user=mysql

ps aux | grep 1495
# → systemd+  1495  0.1  1.8  497648 36340 ?  Ssl  15:37  0:01  mariadbd --user=mysql
```

**解説:** コンテナはホスト OS 上の通常のプロセス。`docker inspect` で取得した PID がホスト側の `ps` にそのまま見える。VM との根本的違い（VM はカーネルごと別、コンテナはカーネル共有のプロセス隔離）をレビューで説明する際の実証に使える。素の `ps`（引数なし）は現在の TTY のプロセスのみ表示するため、Docker プロセスは `ps aux` で確認する。

## PoC記録

（本セッションでは採用なし）

## 現在のファイル状態

- **新規作成:** `secrets/db_password.txt`, `secrets/db_root_password.txt`, `secrets/wp_admin_password.txt`
- **更新:** `dev_docs/phase_plan.md`（完了済みにタスク 4-3 追記）、`dev_docs/inception_progress_snapshot.md`（A'・B1・B2・B4 更新）

## 次のセッションでやること

- **タスク 4-4**（docker-compose.yml に secrets 定義追加）— secrets セクション、各サービスへの配布
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

今日やること: タスク 4-4（docker-compose.yml に secrets 定義追加）
環境: 自宅 M2 Mac + Vagrant

セッション開始時刻の記録（ターミナルで実行し、結果をチャットに貼る）:
date '+%Y-%m-%d %H:%M'
```
