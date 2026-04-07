# セッションログ #0010

> 日付: 2026-04-03
> セッション種別: タスク 2-5（NGINX TLS・443 単体テスト）— 方針 A 採用・手順の記録
> 対応フェーズ: 2
> 開始: 2026-04-03 21:00（ドライバー申告）
> 終了: 2026-04-03 23:00（開始 + 実作業時間に合わせて記録）
> 実作業時間: 2.0h（ドライバー申告）
> 計画時間: 2h（`phase_plan.md` タスク 2-5）

---

## このセッションで完了したこと

- **タスク 2-5 のスコープ**: 「単体テスト」を **TLS・443・証明書・`ssl_protocols` の確認**に限定。
- **方針 A（採用）**: 課題表の「単体」という語感と実装のギャップを、次のように割り切る。
  - **イメージ単体** = ビルド対象は `srcs/requirements/nginx/` の Dockerfile のみ（設定差し替え用の別ファイルは作らない前提）。
  - **最小限の外部** = **`fastcgi_pass` の upstream 名 `wordpress` が名前解決できること**だけを Docker に任せる（＝ユーザ定義ブリッジネットワーク上に、**コンテナ名 `wordpress`** が存在する）。
  - これにより、`torinoue_nginx.conf` 内の `fastcgi_pass wordpress:9000;` による **`[emerg] host not found in upstream`** を避け、nginx が **常駐**し、443 で TLS 疎通テストが可能になる。
- **VM 上で方針 A の手順を実施し、`curl -v` で TLSv1.3 ネゴシエーションと 443 応答を確認**（詳細は PoC 記録）。
- **タスク 2-5 完了**（`phase_plan.md` 完了済みへ反映済み）。

---

## タスク 2-5・方針 A — テスト手順（再現用）

前提: VM 内で作業。既存コンテナが 443 を占有していないこと（`docker ps` で確認。必要なら先に `docker stop`）。

### 1. ビルド

```bash
cd /vagrant/srcs/requirements/nginx
docker build --tag nginx-test:task2-5 ./
```

### 2. ユーザ定義ネットワークの作成

同一ネットワーク上でコンテナ名が DNS 名として解決されるようにする。

```bash
docker network create inception-test-net
```

（既に同名がある場合は `docker network rm inception-test-net` の後に作り直すか、別名を使う。）

### 3. 名前 `wordpress` のスタブ（最小外部）

**目的**: `wordpress` というホスト名がネットワーク内 DNS で解決されることだけを満たす。PHP-FPM が未整備でも、nginx は多くの場合 **起動時に upstream 名を解決できれば**プロセスが立ち上がる（`.php` への実リクエストは 2-6 以降で扱う想定）。

例（Alpine で何もせず常駐だけさせる）:

```bash
docker run -d --name wordpress --network inception-test-net alpine:3.21 sleep infinity
```

※ 既に `wordpress` という名前のコンテナがある場合は、先に `docker rm -f wordpress` するか、別手順で整理する。

### 4. NGINX コンテナの起動（同じネットワーク + 443 公開）

```bash
docker run -d --name nginx-task25 -p 443:443 --network inception-test-net nginx-test:task2-5
```

### 5. 疎通・TLS 確認

```bash
docker ps    # STATUS が Up であること
curl --insecure --verbose https://127.0.0.1:443/
```

確認ポイント（`-v` 出力）:

- `SSL connection using TLSv1.3` または `TLSv1.2`（`torinoue_nginx.conf` の `ssl_protocols TLSv1.2 TLSv1.3` と整合）
- HTTP ステータスやレスポンス本文（静的 `root` が空なら 403 等でも、**TLS レイヤが張れていれば** 2-5 の主目的は達成しうる — ドライバーが合格ラインをどこまでにするかメモしておく）

補助:

```bash
docker logs nginx-task25
```

### 6. 片付け（任意）

```bash
docker stop nginx-task25 wordpress
docker rm nginx-task25 wordpress
docker network rm inception-test-net
```

---

## Spike記録

- **「単体」でも `fastcgi_pass` のホスト名は起動時に解決が必要になりうる**  
  - 単一コンテナ `docker run` だけでは `wordpress` が DNS に存在せず、nginx が **Exited (1)** になりうる。  
  - 方針 A は **Docker の埋め込み DNS（ユーザ定義ネットワーク + コンテナ名）**で、課題用 `nginx.conf` を変えずに起動可能性を確保する。

---

## PoC記録

### PoC: 方針 A による TLS・443 疎通（2026-04-03、VM 内）

- **目的**: `nginx-test:task2-5` が `inception-test-net` 上で起動し、`curl` で **TLS バージョン**と **443 での応答**を確認する。
- **手順（概要）**: `docker network create inception-test-net`（未作成時）→ `docker run -d --name wordpress --network inception-test-net alpine:3.21 sleep infinity` → `docker run -d --name nginx-tesk25 -p 443:443 --network inception-test-net nginx-test:task2-5` → `curl --insecure --verbose https://127.0.0.1:443/`
- **結果（`curl -v` 抜粋）**:
  - `* Connected to 127.0.0.1 (127.0.0.1) port 443`
  - `* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384`
  - `* ALPN, server accepted to use http/1.1`
  - サーバ証明書の subject に `CN=toruinoue`（自己署名）
  - HTTP: `< HTTP/1.1 502 Bad Gateway`（`Server: nginx/1.26.3`）
- **判定**: **タスク 2-5 の主目的（TLS・443）は達成**。TLS は **TLSv1.3** でネゴシエーション済み（`ssl_protocols TLSv1.2 TLSv1.3` と整合）。502 は **`/` が `try_files` 経由で `index.php` に落ち、`fastcgi_pass wordpress:9000` へ送られるが、スタブは PHP-FPM をListenしていない**ため想定どおり。HTTP 200 を出すのはタスク 2-6 以降（実 WP または静的ファイル配置）の範囲。

---

## 現在のファイル状態

| ファイル | 変更内容 |
|---------|---------|
| `session_logs/0010_session_log_inception.md` | 本ファイル（方針 A と手順の記録） |

---

## 次のセッションでやること

- **タスク 2-6**: NGINX + MariaDB 接続テスト（静的ページ）— `phase_plan.md` 参照。

---

## 未解決事項

（あれば）

---

## 新しいチャット開始時のコピペ用指示文

```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール）
- session_logs/ 内の最新セッションログ（最も番号が大きいファイル）

今日やること: タスク 2-6（NGINX + MariaDB 接続テスト・静的ページ）
```
