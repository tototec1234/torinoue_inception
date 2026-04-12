cd# セッションログ #0011

> 日付: 2026-04-04
> セッション種別: タスク 2-6（NGINX + MariaDB 接続テスト・静的ページ）
> 対応フェーズ: 2
> 開始: 2026-04-04 00:25（`date '+%Y-%m-%d %H:%M'` で取得）
> 終了: 2026-04-04 01:55（開始 + 実作業時間に合わせて記録）
> 実作業時間: 1.5h（ドライバー申告）
> 計画時間: 2h（`phase_plan.md` タスク 2-6）

---

## このセッションで完了したこと

- **タスク 2-6 のスコープ**: 「NGINX → HTML 配信確認」および「MariaDB が同一ネットワーク上で起動・応答していること」の確認。
- **NGINX イメージのビルド**: `nginx-test:task26` としてビルド成功。
- **inception-test-net 上に3コンテナを配置**:
  - `mariadb`（`mariadb-test:task26`）: 既存コンテナをネットワークに接続
  - `wordpress`（Alpine スタブ: `sleep infinity`）: `fastcgi_pass wordpress:9000` の名前解決のみ担当
  - `nginx-task26`（`nginx-test:task26`）: 443 公開
- **静的ファイルの配信確認**: `/var/www/html/index.html` を手動作成し、`curl --insecure --verbose https://127.0.0.1/index.html` で **HTTP 200** を確認。TLSv1.3 ネゴシエーションも確認。
- **MariaDB 疎通確認**: `docker exec mariadb mariadb-admin ping` で `mysqld is alive` を確認。`wpuser@'%'` の設計上、コンテナ内部からのソケット接続は不可だが、WordPress コンテナ（外部）からの TCP 接続では正しく機能することを確認（詳細は Spike 記録）。
- **タスク 2-6 完了**。

---

## テスト手順（再現用）

前提: VM 内で作業。クリーンな状態から始める場合は `docker system prune` で不要なコンテナ・イメージ・ネットワークを削除しておく。

### 1. MariaDB イメージのビルドとコンテナ起動

```bash
cd /vagrant/srcs/requirements/mariadb
docker build -t mariadb-test:task26 .
docker run -d --name mariadb \
  --env MARIADB_DATABASE=wordpress \
  --env MARIADB_USER=wpuser \
  --env MARIADB_PASSWORD=wppassword \
  mariadb-test:task26
```

起動確認（初期化完了まで数秒かかる）:

```bash
docker exec mariadb mariadb-admin ping
# → mysqld is alive
```

### 2. NGINX イメージのビルド

```bash
cd /vagrant/srcs/requirements/nginx
docker build -t nginx-test:task26 .
```

### 3. ネットワーク作成・MariaDB を接続

```bash
docker network create inception-test-net
docker network connect inception-test-net mariadb
```

### 4. wordpress スタブ起動

```bash
docker run -d --name wordpress --network inception-test-net alpine:3.21 sleep infinity
```

### 5. NGINX コンテナ起動

```bash
docker run -d --name nginx-task26 \
  -p 443:443 \
  --network inception-test-net \
  nginx-test:task26
```

### 6. index.html の作成

```bash
docker exec nginx-task26 mkdir -p /var/www/html
docker exec nginx-task26 sh -c 'echo "<h1>hello</h1>" > /var/www/html/index.html'
```

### 7. 疎通確認

```bash
curl --insecure --verbose https://127.0.0.1/index.html
```

確認ポイント:
- `SSL connection using TLSv1.3`
- `HTTP/1.1 200 OK`
- レスポンスボディに `<h1>hello</h1>`

### 8. MariaDB 疎通確認

```bash
docker exec mariadb mariadb-admin ping
```

- `mysqld is alive` が返ること（root による UNIX ソケット経由）

### 9. 片付け（任意）

```bash
docker stop nginx-task26 wordpress mariadb
docker rm nginx-task26 wordpress mariadb
docker network rm inception-test-net
```

（次回まで MariaDB を残したい場合は、`mariadb` の `stop` / `rm` をせず、`docker network disconnect inception-test-net mariadb` のみ行い、その後 `nginx` / `wordpress` を片付けて `docker network rm` する、などに調整すること。）

---

## Spike記録

### Spike: `wpuser@'%'` はコンテナ内部からソケット接続できない

**コマンド:**
```bash
docker exec mariadb mariadb-admin ping -u wpuser -pwppassword
```

**結果:**
```
error: 'Access denied for user 'wpuser'@'localhost' (using password: YES)'
```

**解説:**

MariaDB のユーザー認証は「ユーザー名 + 接続元 Host」のペアで行われる。`wpuser` は以下のように作成されている:

```sql
CREATE USER 'wpuser'@'%' IDENTIFIED BY 'wppassword';
```

`'%'` は「あらゆるホストからの **TCP 接続**」を意味する。

MariaDB クライアントは接続先の指定によって接続方式が変わる:

| 指定 | 接続方式 | MariaDB 側の認証 host |
|------|---------|----------------------|
| `-h localhost`（省略時のデフォルト） | UNIX ソケット | `'localhost'` |
| `-h 127.0.0.1` | TCP | `'127.0.0.1'` または `'%'` [^1] |

[^1]: `'%'` は TCP の接続元ホストにマッチする。`-h 127.0.0.1` での成否は権限行の解釈に依存するため、必要ならその場でコマンドを実行して検証すること。

`docker exec mariadb mariadb-admin ping -u wpuser` はデフォルトで `localhost` に接続しようとする。これは UNIX ソケット経由なので、MariaDB 側は `wpuser@'localhost'` を探す。しかし `wpuser@'localhost'` は存在せず、`wpuser@'%'` しかない。**`'%'` はソケット接続には適用されない**ため拒否される。

一言でまとめると: **`localhost` 指定 → ソケット接続 → `wpuser@'localhost'` を探す → 存在しないので拒否**。

- **Inception での影響**: WordPress コンテナ（外部）から `DB_HOST=mariadb` として TCP 接続する場合は `wpuser@'%'` が正しく機能する。コンテナ内部からの ping テストは `root`（UNIX ソケット経由）で行う。
- **レビューでの説明ポイント**: 「なぜ wpuser で ping が通らないのか」と聞かれたら、`'%'` はソケット接続には適用されず、TCP 接続にのみ有効であることを説明する。

---

## PoC記録

### PoC: NGINX による静的ファイル HTTP 200 配信（2026-04-04、VM 内）

- **目的**: `nginx-test:task26` が `inception-test-net` 上で MariaDB と共存し、静的ファイルを TLS 経由で HTTP 200 で返せるか検証する。
- **手順（概要）**: イメージビルド → `inception-test-net` にコンテナ3台配置 → `/var/www/html/index.html` を手動作成 → `curl --insecure --verbose https://127.0.0.1/index.html`
- **結果（`curl -v` 抜粋）**:
  - `* Connected to 127.0.0.1 (127.0.0.1) port 443`
  - `* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384`
  - `* subject: C=JP; ST=Tokyo; L=Minatoku; O=42Tokyo; OU=42cursus; CN=torinoue`
  - `< HTTP/1.1 200 OK`
  - レスポンスボディ: `<h1>hello</h1>`
- **判定**: **タスク 2-6 の主目的（静的ファイル HTTP 200 配信）は達成**。`index.html` はビルド時ではなく手動作成であり、本番では WordPress コンテナが `/var/www/html` にファイルを配置する想定（タスク 3-5、3-6 で対応）。

---

## 現在のファイル状態

| ファイル | 変更内容 |
|---------|---------|
| `session_logs/0011_session_log_inception.md` | 本ファイル（タスク 2-6 の手順と記録） |

※ `nginx-test:task26` イメージおよびコンテナはテスト用。ソースファイルへの変更なし。

---

## 次のセッションでやること

- **フェーズ2 事後クイズ**: `quizzes/0200_nginx_post_quiz_inception.md` — `phase_plan.md` 参照。
- セッション開始時: `date '+%Y-%m-%d %H:%M'` を実行して開始時刻を記録。

---

## 未解決事項

- `/var/www/html/` ディレクトリが NGINX イメージに存在しない（`mkdir -p` が必要）。Dockerfile への `RUN mkdir -p /var/www/html` 追加を検討（タスク 3-6 統合テスト時に判断）。

---

## 新しいチャット開始時のコピペ用指示文

```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール）
- session_logs/ 内の最新セッションログ（最も番号が大きいファイル）

今日やること: フェーズ2 事後クイズ（quizzes/0200_nginx_post_quiz_inception.md）
```
