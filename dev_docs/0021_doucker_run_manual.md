

## 再現手順（成功パターンのみ）

前提: **Vagrant ゲスト内**で Docker を実行。共有フォルダは **`/vagrant` = リポジトリルート**（`srcs/vm/Vagrantfile` の `synced_folder` に準拠）。  
イメージタグ **`mariadb-test:task36` / `wordpress-test:task36` / `nginx-test:task36`** は本セッションでのビルド名（タグは任意に変更可）。

### 1. イメージビルド（ゲスト内）

```bash
docker build -t mariadb-test:task36   srcs/requirements/mariadb
docker build -t wordpress-test:task36 srcs/requirements/wordpress
docker build -t nginx-test:task36     srcs/requirements/nginx
```

### 2. ネットワーク作成

```bash
docker network create test-net
```

### 3. コンテナ起動（順序: MariaDB → WordPress → NGINX）

**注意:** `torinoue_nginx.conf` の `fastcgi_pass wordpress:9000;` より、WordPress コンテナの **`--name` は `wordpress` 固定**。

```bash
docker run -d \
  --name mariadb \
  --network test-net \
  -e MARIADB_DATABASE=wordpress \
  -e MARIADB_USER=wpuser \
  -e MARIADB_PASSWORD=wppassword \
  mariadb-test:task36

docker run -d \
  --name wordpress \
  --network test-net \
  --dns 8.8.8.8 \
  -e DOMAIN_NAME=torinoue.42.fr \
  -e WP_ADMIN_USER=boss42 \
  -e WP_ADMIN_PASSWORD=wpadminpass \
  -e WP_ADMIN_EMAIL=admin@example.com \
  -e WP_USER=wpeditor \
  -e WP_USER_EMAIL=editor@example.com \
  -e WP_USER_PASSWORD=wpeditorpass \
  -e MARIADB_ROOT_PASSWORD=rootpassword \
  -e MARIADB_DATABASE=wordpress \
  -e MARIADB_USER=wpuser \
  -e MARIADB_PASSWORD=wppassword \
  wordpress-test:task36

docker run -d \
  --name nginx \
  --network test-net \
  -p 443:443 \
  nginx-test:task36
```

### 4. 動作確認（ゲスト内）

```bash
docker logs wordpress
docker logs nginx
docker exec wordpress wp --allow-root --path=/var/www/html db check
```

### 5. Mac ブラウザ（ホスト）

1. **`srcs/vm/Vagrantfile`**: `forwarded_port` で **ゲスト 443 → ホスト 443**（本セッションでは `host_ip: "127.0.0.1"` を使用）。変更後は **`vagrant reload`**。
2. Mac の **`/etc/hosts`**: `127.0.0.1 toruinoue.42.fr`（`<login>` は自分の 42 ユーザー名に合わせる）。
3. ブラウザで **`https://toruinoue.42.fr/`**（証明書の詳細は Chrome の「接続は保護されていません」→ 証明書の表示 などで確認可能）。

---

## Spike記録

### Spike: Mac の `curl` が `Could not resolve host` になるのに `ping` は通る

**背景:** `/etc/hosts` に `toruinoue.42.fr` を追加済みでも、`curl` が (6) で失敗することがあった。

**解説:** `HTTP_PROXY` / `HTTPS_PROXY` 等があると、`curl` は名前解決をプロキシ経由にすることがあり、`/etc/hosts` と挙動がずれる。`ping` はプロキシを使わないことが多い。

**確認コマンド例:** `env | grep -i proxy`、必要なら `env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy curl -vk https://toruinoue.42.fr:443/`。

### Spike: `https://toruinoue.42.fr` が `ERR_CONNECTION_REFUSED` になるが `:4443` は通る

**背景:** Vagrant が **ホスト 4443 → ゲスト 443** のとき、ブラウザのデフォルト HTTPS は **443** のため、ホスト 443 に何も無いと拒否になる。

**解説:** 課題どおりポート省略で見るには **ホスト 443 への転送**（本セッションでは `guest: 443, host: 443`）に合わせる。

## PoC記録

### PoC: タスク 3-6 合格基準（3 コンテナ + ブラウザ）

**目的:** NGINX が TLS で待ち、PHP-FPM（WordPress）へ FastCGI で繋ぎ、ブラウザでサイトが表示されることを確認する。

**手順:** 上記「再現手順」に従いコンテナを起動したうえで、Mac で `https://toruinoue.42.fr/` を開く。DB は `wp db check` で確認。

**結果:** WordPress のトップページ表示。Chrome で証明書ビューアを開き、自己署名証明書の内容を確認可能。

**判定:** **達成**（タスク 3-6 完了としてよい）

## 現在のファイル状態

- **`dev_docs/memo.sh`**: 同系の `docker network create` / `docker run` 抜粋あり
- **`srcs/vm/Vagrantfile`**: `guest: 443` → `host: 443`, `host_ip: "127.0.0.1"`（本セッションでブラウザ検証に利用）

## 次のセッションでやること

- **フェーズ 4**（`docker-compose.yml`、secrets、healthcheck、volume 等）— `phase_plan.md` タスク 4-1 から
- セッション開始時: `date '+%Y-%m-%d %H:%M'` を実行して開始時刻を記録

## 未解決事項

- 証明書の **CN** が FQDN と完全一致しない場合（例: CN のみ `toruinoue`）は、将来 **CN/SAN を `toruinoue.42.fr` に揃えた**自己署名証明書へ再生成する余地あり（課題必須かはレビュー方針次第）
- `sendmail: connection refused` は WordPress インストール時のメール送信失敗ログ（本タスクでは未対処）

## 新しいチャット開始時のコピペ用指示文

```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール）
- session_logs/ 内の最新セッションログ（最も番号が大きいファイル）

今日やること: タスク 4-1（一次資料読み込み）または phase_plan に沿った次タスク
環境: 自宅 M2 Mac + Vagrant

セッション開始時刻の記録（ターミナルで実行し、結果をチャットに貼る）:
date '+%Y-%m-%d %H:%M'
```
