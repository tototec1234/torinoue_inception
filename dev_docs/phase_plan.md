# Inception 課題 学習・実装計画 v3

> 更新日: 2026-04-04
> 残り時間: **90時間**

## 基本方針

- **ベースイメージ**: Alpine 3.21 に統一（penultimate stable version）
  - 根拠: [Alpine Linux公式リリースページ](https://alpinelinux.org/releases/) で最新安定版が 3.22、その一つ前が 3.21
  - README にリンク＋スクリーンショットを掲載予定
- **Docker secrets**: 必須として実装（compose file secrets を使用予定、Swarm 不要か要確認）
- **開発環境**: M2 Mac + Vagrant (VMware Fusion) → 完成後に校舎環境 (VirtualBox) へ移植
- **Mandatory パートのみ**

### 参考実装との差別化ポイント（4つ）

1. **Docker secrets の実装**（参考実装は未対応）
2. **MariaDB待機をより堅牢に実装**（ping ループ＋タイムアウト付き）
3. **初期化ガードを MariaDB に明示的に実装**（参考実装はガードなし）
4. **healthcheck の追加**（`depends_on: condition: service_healthy` で確実な起動順制御）

### 環境変数・secrets 設計方針（2026-04-11 決定）

#### 背景・根拠

課題書（inspection_subject.pdf Version 5.2）の要件：
- 環境変数の使用は**必須**（line 174）
- `.env` ファイルの使用は**必須**（line 175-176）
- Docker secrets は**強く推奨**（line 176-177）
- Git リポジトリに認証情報があると**失敗**（line 177-179, 249-252）
- ディレクトリ構造例に `secrets/` と `srcs/.env` が両方記載（line 200-214）

kamitsui 参考実装は Docker secrets を採用していない（`env_file: .env` のみ）。本実装では課題書の推奨に従い Docker secrets を採用する。

#### 方針

| 項目 | 方針 |
|------|------|
| `.env` | 非機密情報のみを記載し、**git 管理する**（`.gitignore` から除外） |
| `secrets/` | パスワード等の機密情報を格納し、**git 管理しない**（`.gitignore` で除外） |
| Docker secrets | compose file secrets を使用（Swarm 不要） |

#### `.env` に記載する変数（非機密情報）

```
YOUR_LEARNER_USERNAME=torinoue
DOMAIN_NAME=${YOUR_LEARNER_USERNAME}.42.fr
MARIADB_DATABASE=wordpress
MARIADB_USER=wpuser
WP_ADMIN_USER=boss42
WP_ADMIN_EMAIL=admin@example.com
WP_USER=wpeditor
WP_USER_EMAIL=editor@example.com
```

- `YOUR_LEARNER_USERNAME`: 課題書の "your learner's username" に対応。`docker-compose.yml` の `device:` パスと `DOMAIN_NAME` で参照
- `${USER}` は使用しない（Vagrant 環境で `vagrant` になるため）

#### `secrets/` に格納するファイル（機密情報）

```
secrets/
├── db_password.txt          # MariaDB ユーザーのパスワード（1行、改行なし）
├── db_root_password.txt     # MariaDB root のパスワード（1行、改行なし）
└── wp_admin_password.txt    # WordPress admin のパスワード（1行、改行なし）
```

#### docker-compose.yml での secrets 定義

```yaml
secrets:
  db_password:
    file: ../secrets/db_password.txt
  db_root_password:
    file: ../secrets/db_root_password.txt
  wp_admin_password:
    file: ../secrets/wp_admin_password.txt

services:
  mariadb:
    secrets:
      - db_password
      - db_root_password
    # ...
```

コンテナ内では `/run/secrets/<name>` として配置され、entrypoint.sh で `cat /run/secrets/db_password` で読み取る。

#### .gitignore

```
secrets/
.vagrant/
.DS_Store
project.zip
```

注: `srcs/.env` は非機密情報のみなので **除外しない**（git 管理する）。

---

## AI協働ルール（AI-Navigated Pair Programming with Scaffolding）

これは42Tokyoの学習課題であり、学習者本人が手を動かすことが必須。
AIはペアプログラミングの **Navigator**（方向を示す人）に徹し、**Driver**（コードを書く人）にならない。

| 用語 | 分野 | この課題での意味 |
|------|------|----------------|
| Scaffolding（足場かけ） | 教育学 | AIがヒント・構造を提供し、学習者が自ら実行する |
| Pair Programming（Navigator/Driver） | アジャイル開発 | Driver=学習者、Navigator=AI |
| Human-in-the-Loop（HITL） | AI運用 | AIが提案し、人間が判断・実行する |

### 実装タスクの進め方

1. **AIが解説・ヒントを出す**（概念、設計方針、確認すべきこと）
2. **AIが確認コマンドを提示** → ユーザーがターミナルで実行し結果を貼る
3. **AIが構造・ヒントを示す** → ユーザーがvim等でコーディング
4. **ユーザーがコードを貼る** → AIがレビュー・フィードバック
5. **根拠はコメントとしてコードに埋め込む**（一次資料URLを含む）

### AIの禁止事項

- ファイルを直接編集・作成しない（運用ドキュメントやセッションログは除く）
- 完成コードをそのまま提示しない（部分的なヒントやスケルトンは可）
- git操作を実行しない（コマンドの提案のみ）
- ユーザーの代わりにターミナルコマンドを実行しない

### AIがやってよいこと

- 概念の解説、設計判断の根拠説明
- 確認用コマンドの提示
- コードのスケルトン（穴埋め形式）の提示
- ユーザーが書いたコードのレビュー
- セッションログ・phase_plan.md の更新（運用ドキュメント）
- 一次資料のURL提示
- セッション終了時に、Spike記録・PoC記録の記載対象をユーザーと協議して選定し、セッションログに記録する

### phase_plan.md の更新手順（ドライバー確認付き）

`phase_plan.md` の「完了済み」チェックや日付の更新は、**ドライバー（学習者）が内容を確認・承認したあと**に AI が実行する。

| タイミング | 記録先 | 内容 |
|-----------|--------|------|
| タスク完了をドライバーが宣言したとき | `phase_plan.md` の「完了済み」 | 該当タスクを `[x]` にし、必要なら一行メモを追記 |
| 中間チェックポイントのみのとき | セッションログ（＋任意で下記「進行中」） | 完了チェックは保留。読了範囲・実施コマンド等をログに残す |
| 運用ルールそのものの変更 | `phase_plan.md` 本節 | ドライバーが方針を明示してから AI が追記 |

AI は、ドライバーから「phase_plan をこう更新して」と明示された内容以外を **推測で完了済みにしない**。

### 適用先

- `.cursor/rules/scaffolding-workflow.mdc` に同内容のルールファイルを配置済み
- 新しいチャットでも自動的にAIに適用される

---

## セッション運用ルール

### 1セッションの単位

**基本: 1タスク = 1セッション**（`phase_plan.md` のタスク表の1行）

| タスク時間 | セッション構成 |
|-----------|--------------|
| 1h | 隣接する2〜3タスクをまとめて1セッション可 |
| 2h | 1タスク = 1セッション（基本）|
| 3〜4h | 必ず1タスク = 1セッション |

フェーズ単位の事前クイズ・事後クイズはそれぞれ独立した1セッション。

### セッション開始時（AIへの指示文テンプレート）

新しいチャットの冒頭に以下をコピペする:

```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール）
- session_logs/ 内の最新セッションログ（最も番号が大きいファイル）

今日やること: [タスク番号とタスク名] 例: タスク1-4（MariaDB Dockerfile 作成）

セッション開始時刻の記録（ターミナルで実行し、結果をチャットに貼る）:
date '+%Y-%m-%d %H:%M'
```

### セッション終了時にAIがやること（必須）

1. **ドライバーの確認のうえ**、完了したタスクを `phase_plan.md` の「完了済み」に追記（中間進捗のみのセッションではセッションログに記録し、完了チェックは保留可。手順は上記「phase_plan.md の更新手順」参照）
2. 次のセッションログを作成してコミット:

```bash
# ファイル: session_logs/NNNN_session_log_inception.md
# NNNN = 前回ログの番号 + 1（0パディング4桁）
```

セッションログの構成:

```markdown
# セッションログ #NNNN

> 日付: YYYY-MM-DD
> セッション種別: [事前クイズ / タスクX-Y / 事後クイズ / 統合テスト 等]
> 対応フェーズ: X
> 開始: YYYY-MM-DD HH:MM（AIが `date` コマンドで取得）
> 終了: YYYY-MM-DD HH:MM（AIが `date` コマンドで取得）
> 実作業時間: X.Xh（ユーザー自己申告）
> 計画時間: Xh（phase_plan.md のタスク表から転記）

## このセッションで完了したこと
（箇条書き）

## Spike記録
（技術的な不確実性を解消するための調査・実験の記録）
（記載対象が多数の場合、セッション終了時にAIと協議して選定する）
（各Spikeは以下の構成で記載する:）
- **Spikeタイトル**
- コマンド（実行したコマンド全文）
- 結果（実行結果）
- 解説（なぜこうなるか、Inception での影響、レビューでの説明ポイント）

## PoC記録
（「この方法で動くか？」を最小限のコードで検証した記録）
（記載対象が多数の場合、セッション終了時にAIと協議して選定する）
（各PoCは以下の構成で記載する:）
- **PoCタイトル**
- 目的（何の実現可能性を検証するか）
- 手順（実行したコマンドや操作）
- 結果（実行結果）
- 判定（成功 / 失敗 + 理由）

## 現在のファイル状態
（変更・作成したファイルのみ記載）

## 次のセッションでやること
（タスク番号と名前、必要なら注意事項）
- セッション開始時: `date '+%Y-%m-%d %H:%M'` を実行して開始時刻を記録（上記「開始」欄やチャットへの貼り付けに用いる）

## 未解決事項
（あれば）

## 新しいチャット開始時のコピペ用指示文
（上記テンプレートに今日やることを埋めたもの）
```

AIの動作:
- セッション開始時: `date '+%Y-%m-%d %H:%M'` を実行して開始時刻を記録
- セッション終了時: 同コマンドで終了時刻を取得、ユーザーに実作業時間を確認して記録

3. git commit（**提案のみ。実行はユーザーの明示的な指示があるまで行わない**）:
```bash
git add .
git commit -m "タスクX-Y: [完了内容の一言説明]"
```

---

## クイズ運用ルール

各フェーズおよび主要タスクに対して、以下のクイズを実施する。

### 保存先

`quizzes/` ディレクトリ（プロジェクトルート直下）

### ファイル命名規則

```
XXYY_<topic>_<pre|post>_quiz_inception.md
```

- `XX`: フェーズ番号（0パディング2桁）
- `YY`: タスク番号（0パディング2桁、フェーズ単位のクイズは `00`）
- `<topic>`: トピック名（スネークケース）
- `<pre|post>`: 事前 or 事後

**例:**
- フェーズ1の事前クイズ → `0100_alpine_mariadb_pre_quiz_inception.md`
- タスク1-4の事後ミニクイズ → `0104_mariadb_dockerfile_post_quiz_inception.md`
- フェーズ3の事後クイズ → `0300_wordpress_alpine_post_quiz_inception.md`

**理由:** `cat` で補完する際にテンキーだけで番号選択でき、常に昇順に並ぶ。

| 種類 | タイミング | 目的 | 保存先 |
|------|-----------|------|--------|
| **事前クイズ (pre)** | フェーズ/タスク開始前 | 現時点の理解度を測定。何がわかっていないかを自覚する | `quizzes/XXYY_<topic>_pre_quiz_inception.md` |
| **事後クイズ (post)** | フェーズ/タスク完了後 | 定着度を確認。弱点を洗い出す | `quizzes/XXYY_<topic>_post_quiz_inception.md` |

### クイズMDの各Q構成（pre/post共通）

各Qは以下の構成とする。**見出しは短いタイトル、直下に質問文の全文を記載**すること。
後から見直したときに質問内容が一目でわかるようにするため。

```
## Q1. 短いタイトル

質問文の全文をここに記載する。選択肢がある場合はリストで列挙する。

**自分の回答：**
（ここに自分の回答）

**正解：**
（正解の内容）

**解説：**
（解説）

**一次資料：**
- [リンクテキスト](URL)
```

### クイズMD作成フロー（AI と ドライバーの役割分担）

AIが先に正解・解説を書くと、ドライバーの視界に答えが入り自分で考える機会を奪う。そのため以下のフローで進める。

| ステップ | 誰が | やること |
|---------|------|---------|
| 1. MD 作成 | **AI** | 問題文・選択肢・「自分の回答：（ここに記入）」・一次資料 のみを書いた MD を作成。**正解・解説は書かない** |
| 2. 解答 | **ドライバー** | 「自分の回答」欄を埋める |
| 3. 提出 | **ドライバー** | 埋めた MD をチャットに貼る |
| 4. 採点 | **AI** | 正解・解説を各Qに追記し、MD を更新する |

### postクイズ結果MDの構成

```
# Inception レビュー対策ノート - ○○編

## Q1〜Qn: 問題・自分の回答・正解・解説（質問文の全文を必ず含める）

## 今日詰まったポイント（実装メモ）

## レビュー想定問答集（弱点中心）
  ← postクイズで間違えた/曖昧だった箇所を重点的に
```

---

## 現状分析（2026-04-04時点）

### 完了済み
- [x] Vagrant + VMware Fusion 環境構築（Vagrantfile, init.sh）
- [x] MariaDB コンテナ（Dockerfile + init.sh）基本動作確認済み（Debian bookworm）
- [x] WordPress コンテナ（Dockerfile + init.sh）着手
- [x] WordPress 事前クイズ実施済み → `quizzes/0000_wordpress_pre_quiz_inception.md`（v1計画以前に実施）
- [x] MariaDB 事後クイズ実施済み → `quizzes/0000_mariadb_post_quiz_inception.md`（v1計画以前に実施）
- [x] フェーズ1 事前クイズ実施済み → `quizzes/0100_alpine_mariadb_pre_quiz_inception.md`
- [x] タスク 1-1: Alpine 3.21 の M2 Mac + Vagrant 動作検証 → **OK**（aarch64, apk, mariadbd 11.4.8 全て動作確認）
- [x] タスク 1-2: 参考実装の MariaDB 精読 → 事後クイズ `quizzes/0102_mariadb_reference_post_quiz_inception.md`
- [x] タスク 1-3: 一次資料の読み込み（mariadb-install-db 公式ドキュメント + Alpine Wiki MariaDB）
- [x] AI協働ワークフロー定義（横断的施策）: AI-Navigated Pair Programming with Scaffolding 方式の策定、`.cursor/rules/scaffolding-workflow.mdc`（Policy as Code）+ `phase_plan.md`（運用ドキュメント）に成文化
- [x] タスク 1-4: MariaDB Dockerfile を Alpine 3.21 で新規作成 → ビルド成功、イメージ内部検証完了
- [x] タスク 1-5: `zaphod-mariadb.cnf` 作成 → `bind-address = 0.0.0.0`、`skip-networking = 0` で TCP 有効化、アルファベット順制御
- [x] タスク 1-6: `entrypoint.sh` 本実装完成 → 初期化ガード + ping ループ（42回タイムアウト）+ `exec mariadbd`
- [x] タスク 1-7: MariaDB 単体テスト → 5段階初期化フロー確認、DB・ユーザー作成確認、全項目合格
- [x] フェーズ1 事後クイズ → `quizzes/0100_alpine_mariadb_post_quiz_inception.md`（全18問、弱点の洗い出し完了）
- [x] フェーズ2 事前クイズ → `quizzes/0200_nginx_pre_quiz_inception.md`（全18問、弱点の洗い出し完了）
- [x] タスク 2-1: NGINX + TLS の概念学習 → 一次資料（Beginner’s Guide / `ngx_http_ssl_module` / RFC 8446 ほか）読了、`ngx_http_fastcgi_module` 確認、リバースプロキシ／**上流（upstream）** の整理 → `dev_docs/nginx_reverse_proxy_upstream_memo.md`
- [x] タスク 2-2: 参考実装の NGINX 精読（`Vagrant_sample` の Dockerfile + `nginx.conf`）→ 実装と横断して消化
- [x] タスク 2-3: NGINX 用 Dockerfile 作成 → Alpine 3.21、`openssl`、自己署名証明書、`ENTRYPOINT` と `daemon off` 等 → `srcs/requirements/nginx/Dockerfile`
- [x] タスク 2-4: `nginx.conf` 作成 → TLS、443、`fastcgi_pass`、静的配信 → `srcs/requirements/nginx/conf/torinoue_nginx.conf`（学習メモ: `dev_docs/inception_nginx_daemon_memo.md`, `dev_docs/docker_nginx_study.md`）。**タスク 2-4 専用の事後ミニクイズは実施しない**（`0200_nginx_pre_quiz_inception.md` で `ssl_protocols` / `try_files` / `fastcgi_pass` のサービス名解決などを既にカバーしたため、計画から除外）
- [x] タスク 2-5: NGINX 単体テスト（TLS・443）→ ユーザ定義ネットワーク + コンテナ名 `wordpress` スタブ（方針 A）、`curl -v` で TLSv1.3 確認 → `session_logs/0010_session_log_inception.md`
- [x] タスク 2-6: NGINX + MariaDB 接続テスト（静的ページ）→ `inception-test-net` 上で NGINX・MariaDB・`wordpress` スタブを配置、`index.html` を手動配置して `curl` で HTTP 200、MariaDB は `mariadb-admin ping` で確認 → `nginx.conf` 変更なし → `session_logs/0011_session_log_inception.md`
- [x] フェーズ2 事後クイズ → `quizzes/0200_nginx_post_quiz_inception.md`（全13問、選択式7/7 全問正解、弱点: Q11 設計レベルの説明力・Q7 `docker network connect` の正確な理解）
- [x] タスク 0-1: 機密情報の扱いと secrets ディレクトリの構成の検討 → 環境変数・secrets 設計方針を「基本方針」セクションに追記、`YOUR_LEARNER_USERNAME` 変数の採用決定
- [x] タスク 3-1: 参考実装の WordPress 精読 → Dockerfile（Alpine 3.21, PHP拡張8個, wp-cli）, entrypoint.sh（MariaDB待機タイムアウト付き, wp-config生成, コアDL, 2ユーザー作成）, www.conf（PHP-FPM設定, デフォルト値採用）作成完了。重要な設計判断: `wp core download` のタイミングを Dockerfile から entrypoint.sh に変更（bind mount 対応）
- [x] タスク 3-2: WordPress Dockerfile 詳細検証 → `dev_docs/0409php_packages.md` に基づく最小 `apk` 構成、`COPY`/wp-cli 手順整理、`docker run --entrypoint php83 … -m` でモジュール確認。課題書に拡張個数の義務は無く、計画の「13個」は誤記のため撤廃方針を確認
- [x] タスク 3-3: `www.conf` 作成完了（`listen = 9000`、Alpine デフォルト `pm.*` 採用）— 3-1 で初版作成、本セッションでレビュー・完了宣言
- [x] タスク 3-5: MariaDB + WordPress 2 コンテナテスト → `inception-test-net` 上で結線、`mariadb-client`・`memory_limit`・entrypoint 順（core DL → `wp config create`）を整理、`wp db check` で全テーブル OK → `session_logs/0020_session_log_inception.md`
- [x] タスク 3-6: 3コンテナ統合テスト（NGINX追加）→ ユーザ定義ネットワーク `test-net`、`docker run` で 3 サービス、NGINX `-p 443:443`、Vagrant `443→443` + Mac の `/etc/hosts` で **`https://toruinoue.42.fr/`** をブラウザ確認 → `session_logs/0021_session_log_inception.md`

### 発見された重大な問題（レビュー結果）
1. ~~管理者ユーザー名違反: `wpadmin` → "admin" を含む~~ → `boss42` に修正済み
2. ~~WordPress Dockerfile URL typo~~ → 修正済み
3. docker-compose.yml: networks なし、volume driver_opts なし、restart なし（課題要件違反）
4. ~~NGINX 未実装~~ → Dockerfile・`nginx.conf` は実装済み、**タスク 2-5・2-6（TLS 単体テスト、NGINX + MariaDB 共存での静的 HTML 配信）完了**（compose 統合は未）
5. secrets 未設定
6. ベースイメージ: Debian bookworm → Alpine 3.21 へ全面変更が必要
7. WordPress Dockerfile: PHPモジュール ~~拡張が不足~~ 最小構成で 3-2 完了 必要なモジュールは後にテストして見極める
8. MariaDB init.sh: `--skip-password` は MariaDB では機能しない可能性
9. WordPress init.sh: MariaDB 待機ロジックがない（致命的）
10. php-fpm バージョン番号ハードコード（Alpine 化で壊れる）

---

## フェーズ一覧（90時間）

| # | フェーズ | 時間 | クイズ |
|---|---------|------|--------|
| 0 | 横断的タスク（Cross-cutting） | - | - |
| 1 | Alpine 3.21 基盤構築 + MariaDB 書き直し | 14h | pre + post |
| 2 | NGINX コンテナ構築 | 14h | pre + post |
| 3 | WordPress コンテナ再構築 | 12h | pre + post |
| 4 | Docker Compose 統合 + secrets + healthcheck | 14h | pre + post |
| 5 | Makefile + テスト | 7h | post のみ |
| 6 | ドキュメント作成 | 11h | post のみ |
| 7 | 校舎環境移植 | 9h | post のみ |
| 8 | レビュー準備 | 11h | 総合クイズ |
| **合計** | | **92h** | |

---

## フェーズ 0: 横断的タスク（Cross-cutting）

計画外に発生した設計検討、方針決定、環境問題の解決など、特定フェーズに属さない横断的タスクを記録する。

| # | タスク | 時間 | 実施日 | 備考 |
|---|--------|------|--------|------|
| 0-1 | 機密情報の扱いと secrets ディレクトリの構成の検討 | 2h | 2026-04-11 | 環境変数・secrets 設計方針を決定、`YOUR_LEARNER_USERNAME` 変数の採用 |

### 横断的タスク発生時の運用ルール

1. 横断的タスクは「フェーズ 0」に追加する（0-1, 0-2, ... と番号を振る）
2. 既存フェーズのタスク番号は変更しない（過去のセッションログとの整合性を維持）
3. 横断的タスクのセッションログには、「次のセッションでやること」に**元のフェーズの継続タスク**を記載する
4. 「最新のセッションログを読め」というルールはそのまま維持する

---

## フェーズ 1: Alpine 3.21 基盤構築 + MariaDB 書き直し（14時間）

### 事前クイズ → `quizzes/0100_alpine_mariadb_pre_quiz_inception.md`
- Alpine と Debian の違い（パッケージマネージャ、シェル、ユーザー管理）
- `apk` の基本コマンド
- Alpine の `ash` と `bash` の違い
- MariaDB の `mariadb` コマンドと MySQL の `mysql` コマンドの違い
- PID 1 の意味と `exec` の役割
- `CMD` vs `ENTRYPOINT` の違い

| # | タスク | 時間 | 備考 |
|---|--------|------|------|
| 1-1 | Alpine 3.21 の M2 Mac + Vagrant 動作検証 | 2h | `FROM alpine:3.21` でビルド＋基本コマンド実行テスト |
| 1-2 | 参考実装の MariaDB 精読・写経 | 2h | Dockerfile, my.cnf, entrypoint.sh の全行を理解 |
| 1-3 | 一次資料の読み込み | 2h | [mariadb-install-db](https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db), [Alpine Wiki](https://wiki.alpinelinux.org/wiki/MariaDB) |
| 1-4 | MariaDB Dockerfile を Alpine 3.21 で新規作成 | 3h | 参考実装を理解した上で、自分の設計で書く |
| 1-5 | my.cnf 作成 | 1h | bind-address, port, skip-networking 設定 |
| 1-6 | entrypoint.sh 作成 | 2h | 初期化ガード + ping 待機 + 冪等な SQL + exec mariadbd |
| 1-7 | 単体テスト | 1h | コンテナ起動 → mariadb-admin ping → クライアント接続 |

**タスク 1-2 の事後ミニクイズ → `quizzes/0102_mariadb_reference_post_quiz_inception.md`**
- `mariadb-install-db` の役割とビルド時実行の問題点
- 一時起動 → シャットダウン → 本番起動の理由
- `sleep` 固定待機の問題点と改善方法
- `IF NOT EXISTS` と冪等性
- `apk add --no-cache` の意味

**タスク 1-4 の事後ミニクイズ → `quizzes/0104_mariadb_dockerfile_post_quiz_inception.md`**
- `mariadbd` と `mysqld` の違い
- Alpine で MariaDB をインストールするパッケージ名
- `ENTRYPOINT` と `CMD` の使い分け

**タスク 1-6 の事後ミニクイズ → `quizzes/0106_mariadb_entrypoint_post_quiz_inception.md`**
- `--skip-networking` の意味
- 初期化ガード `if [ ! -d "/var/lib/mysql/mysql" ]` の仕組み
- `exec` を使わないとどうなるか
- ソケット vs TCP 接続の違い

### 事後クイズ → `quizzes/0100_alpine_mariadb_post_quiz_inception.md`
- 上記ミニクイズの弱点を中心に
- レビュー想定問答集付き

---

## フェーズ 2: NGINX コンテナ構築（14時間）

### 事前クイズ → `quizzes/0200_nginx_pre_quiz_inception.md`
- TLS とは何か、SSL との違い
- TLSv1.2 と TLSv1.3 の違い
- 自己署名証明書とは何か
- リバースプロキシとは何か
- `fastcgi_pass` とは何か
- NGINX の設定ファイル構造（events, http, server, location）

| # | タスク | 時間 | 備考 |
|---|--------|------|------|
| 2-1 | NGINX + TLS の概念学習 | 3h | 一次資料: [nginx.org](https://nginx.org/en/docs/), [RFC 8446 (TLS 1.3)](https://datatracker.ietf.org/doc/html/rfc8446) |
| 2-2 | 参考実装の NGINX 精読 | 1h | Dockerfile + nginx.conf の全行理解 |
| 2-3 | Dockerfile 作成 | 2h | Alpine 3.21, openssl, 自己署名証明書 |
| 2-4 | nginx.conf 作成 | 4h | TLSv1.2/1.3 のみ、443、fastcgi_pass、静的ファイル |
| 2-5 | 単体テスト | 2h | `curl -kv https://localhost:443` でTLSバージョン確認 |
| 2-6 | NGINX + MariaDB 接続テスト（静的ページ） | 2h | NGINX → HTML 配信確認 |

### 事後クイズ → `quizzes/0200_nginx_post_quiz_inception.md`
- レビュー想定問答集付き

---

## フェーズ 3: WordPress コンテナ再構築（12時間）

### 事前クイズ → `quizzes/0300_wordpress_alpine_pre_quiz_inception.md`
- PHP-FPM とは何か、なぜ NGINX が直接 PHP を実行できないのか
- `www.conf` の `listen = 9000` の意味
- wp-cli の主要コマンド（core download, config create, core install, user create）
- Alpine での PHP パッケージ名の違い（php83 等）
- `--allow-root` を使うべきか否か

| # | タスク | 時間 | 備考 |
|---|--------|------|------|
| 3-1 | 参考実装の WordPress 精読 | 2h | Dockerfile + www.conf + entrypoint.sh 全行理解 |
| 3-2 | Dockerfile 作成 | 3h | Alpine 3.21, `0409php_packages.md` 最小構成、wp-cli、検証手順はセッション #0019 |
| 3-3 | www.conf 作成 | 1h | listen=9000, user設定、pm設定 |
| 3-4 | entrypoint.sh 作成 | 3h | MariaDB ping 待機（タイムアウト付き）、wp 設定、2ユーザー作成 |
| 3-5 | MariaDB + WordPress 2コンテナテスト | 2h | wp-config.php 生成確認、DB接続確認 |
| 3-6 | 3コンテナ統合テスト（NGINX追加） | 1h | ブラウザで `https://toruinoue.42.fr` アクセス |

**タスク 3-4 の事後ミニクイズ → `quizzes/0304_wordpress_entrypoint_post_quiz_inception.md`**
- MariaDB 待機ループの仕組みとタイムアウトの必要性
- `wp core install` と `wp core download` の違い
- 管理者ユーザー名に "admin" を含んではならない理由

### 事後クイズ → `quizzes/0300_wordpress_alpine_post_quiz_inception.md`
- レビュー想定問答集付き

---

## フェーズ 4: Docker Compose 統合 + secrets + healthcheck（14時間）

### 事前クイズ → `quizzes/0400_compose_secrets_pre_quiz_inception.md`
- Docker named volume と bind mount の違い
- `driver_opts` の `type: none, device: ..., o: bind` の意味
- Docker secrets（compose file secrets）の仕組み
- `healthcheck` の構文と `depends_on: condition:` の使い方
- Docker network（bridge）の仕組み
- `restart: always` の動作

| # | タスク | 時間 | 備考 |
|---|--------|------|------|
| 4-1 | 一次資料読み込み | 2h | [Compose file secrets](https://docs.docker.com/compose/how-tos/use-secrets/), [healthcheck](https://docs.docker.com/reference/compose-file/services/#healthcheck), [volumes](https://docs.docker.com/reference/compose-file/volumes/) |
| 4-2 | docker-compose.yml 完成 | 3h | 3サービス、networks(bridge)、volumes(driver_opts)、restart、healthcheck |
| 4-3 | secrets ディレクトリ＋ファイル作成 | 1h | db_password.txt, db_root_password.txt, wp_admin_password.txt |
| 4-4 | docker-compose.yml に secrets 定義追加 | 2h | secrets セクション、各サービスへの配布 |
| 4-5 | 各 entrypoint.sh を secrets 読み取り対応に修正 | 2h | `/run/secrets/<name>` からの読み取り |
| 4-6 | .env をパスワード類排除、非機密値のみに整理 | 1h | DOMAIN_NAME, MYSQL_DATABASE 等のみ残す |
| 4-7 | 統合テスト | 3h | `make up` → 全コンテナ起動 → WP アクセス → コンテナ kill → 自動再起動 → ボリューム永続化確認 |

**タスク 4-2 の事後ミニクイズ → `quizzes/0402_compose_yml_post_quiz_inception.md`**
- `network: host` や `--link` が禁止されている理由
- named volume の `driver_opts` で bind しているのに bind mount ではない理由
- `depends_on` だけでは不十分な理由と `healthcheck` の役割

**タスク 4-4 の事後ミニクイズ → `quizzes/0404_compose_secrets_post_quiz_inception.md`**
- compose file secrets と Docker Swarm secrets の違い
- secrets が `/run/secrets/` に配置される仕組み
- .env と secrets の使い分け基準

### 事後クイズ → `quizzes/0400_compose_secrets_post_quiz_inception.md`
- レビュー想定問答集付き

---

## フェーズ 5: Makefile + テスト（7時間）

| # | タスク | 時間 | 備考 |
|---|--------|------|------|
| 5-1 | Makefile 作成 | 2h | `all`(=up), `up`, `down`, `down-v`, `re` |
| 5-2 | クリーンビルドテスト | 2h | `make re` でゼロからの再構築 |
| 5-3 | エッジケーステスト | 2h | kill→restart、永続化、禁止事項チェック |
| 5-4 | 課題要件チェックリスト照合 | 1h | 全要件を1つずつ確認 |

### 事後クイズ → `quizzes/0500_makefile_test_post_quiz_inception.md`
- `tail -f`, `sleep infinity`, `while true` が禁止される理由
- PID 1 のベストプラクティス
- `latest` タグが禁止される理由
- コンテナ再起動のテスト方法
- レビュー想定問答集付き

---

## フェーズ 6: ドキュメント作成（11時間）

| # | タスク | 時間 | 備考 |
|---|--------|------|------|
| 6-1 | README.md | 4h | 英語。4つの比較（VM vs Docker, Secrets vs Env, Docker Network vs Host, Volumes vs Bind Mounts）、Resources、AI使用説明 |
| 6-2 | USER_DOC.md | 2.5h | サービス概要、起動/停止、アクセス方法、認証情報管理 |
| 6-3 | DEV_DOC.md | 2.5h | 環境構築手順、ビルド/起動、コンテナ管理、データ永続化 |
| 6-4 | Spike記録集約ドキュメント作成 | 1h | 全セッションログからSpike記録を横断収集。保存先: `session_logs/spike_records.md` |
| 6-5 | PoC記録集約ドキュメント作成 | 1h | 全セッションログからPoC記録を横断収集。保存先: `session_logs/poc_records.md` |

### 事後クイズ → `quizzes/0600_docs_post_quiz_inception.md`
- VM vs Docker: カーネル共有の有無、隔離の仕組み（namespaces/cgroups）、Inception で両方使う理由
- Secrets vs Env: `docker inspect` での可視性、`/run/secrets/` マウントの仕組み、課題要件での使い分け
- Docker Network vs Host: bridge ネットワークの隔離性、ポート公開の違い、Inception での設計意図
- Volumes vs Bind Mounts: Docker 管理 vs ホストパス依存、ライフサイクルの違い、永続化の設計判断
- レビュー想定問答集付き

---

## フェーズ 7: 校舎環境移植（9時間）

| # | タスク | 時間 | 備考 |
|---|--------|------|------|
| 7-1 | Vagrantfile を VirtualBox 対応に変更 | 2h | provider 切り替え、arm64 → x86_64 確認 |
| 7-2 | 校舎環境ビルド＆テスト | 4h | ネットワーク制限、ディスク容量差異 |
| 7-3 | 最終動作確認 | 3h | 全フロー通しテスト |

### 事後クイズ → `quizzes/0700_migration_post_quiz_inception.md`
- VMware Fusion と VirtualBox の違い
- bento/ubuntu-22.04 と arm64 版の違い
- 校舎環境での制約事項
- レビュー想定問答集付き

---

## フェーズ 8: レビュー準備（11時間）

| # | タスク | 時間 | 備考 |
|---|--------|------|------|
| 8-1 | 全 post クイズの弱点復習 | 3h | `quizzes/` 内の全 md を見直し |
| 8-2 | 総合レビュークイズ | 3h | 全範囲横断 |
| 8-3 | ライブ修正練習 | 3h | nginx.conf 変更、ユーザー追加等のオンザフライ |
| 8-4 | 参考文献リスト整理 | 2h | 一次/二次資料の対応表 |

### 総合クイズ → `quizzes/0800_final_review_quiz_inception.md`
全フェーズ横断。以下のカテゴリを網羅:
- Docker 基礎（PID 1, ベースイメージ, Dockerfile ベストプラクティス）
- Docker Compose（networks, volumes, secrets, restart, healthcheck）
- MariaDB（初期化フロー, 冪等性, ソケット vs TCP）
- NGINX（TLS, リバースプロキシ, fastcgi）
- WordPress（PHP-FPM, wp-cli, ユーザー管理）
- インフラ全体（通信フロー, セキュリティ, 永続化）

---

## クイズ成果物一覧

すべて `quizzes/` ディレクトリに保存。

### 既存（v1計画以前に実施、移行済み）

| ファイル名 | 内容 |
|-----------|------|
| `0000_wordpress_pre_quiz_inception.md` | WordPress 事前クイズ（Debian 時代） |
| `0000_mariadb_post_quiz_inception.md` | MariaDB 事後クイズ（Debian 時代） |

### フェーズ単位

| ファイル名 | フェーズ | 種類 |
|-----------|---------|------|
| `0100_alpine_mariadb_pre_quiz_inception.md` | 1 | pre |
| `0100_alpine_mariadb_post_quiz_inception.md` | 1 | post |
| `0200_nginx_pre_quiz_inception.md` | 2 | pre |
| `0200_nginx_post_quiz_inception.md` | 2 | post |
| `0300_wordpress_alpine_pre_quiz_inception.md` | 3 | pre |
| `0300_wordpress_alpine_post_quiz_inception.md` | 3 | post |
| `0400_compose_secrets_pre_quiz_inception.md` | 4 | pre |
| `0400_compose_secrets_post_quiz_inception.md` | 4 | post |
| `0500_makefile_test_post_quiz_inception.md` | 5 | post |
| `0600_docs_post_quiz_inception.md` | 6 | post |
| `0700_migration_post_quiz_inception.md` | 7 | post |
| `0800_final_review_quiz_inception.md` | 8 | 総合 |

### タスク単位（事後ミニクイズ）

| ファイル名 | タスク | 内容 |
|-----------|--------|------|
| `0102_mariadb_reference_post_quiz_inception.md` | 1-2 | 参考実装の MariaDB 精読 |
| `0104_mariadb_dockerfile_post_quiz_inception.md` | 1-4 | MariaDB Dockerfile 理解 |
| `0106_mariadb_entrypoint_post_quiz_inception.md` | 1-6 | MariaDB entrypoint.sh 理解 |
| `0304_wordpress_entrypoint_post_quiz_inception.md` | 3-4 | WordPress entrypoint.sh 理解 |
| `0402_compose_yml_post_quiz_inception.md` | 4-2 | docker-compose.yml 理解 |
| `0404_compose_secrets_post_quiz_inception.md` | 4-4 | Docker secrets 理解 |

---

## 未確認事項（要フォローアップ）

- [ ] Docker secrets: Swarm なしの compose file secrets で要件を満たすか（同期 or 先輩に確認、**M2 Mac 版完成後**）
- [x] ~~Alpine 3.21 が M2 Mac + Vagrant (VMware Fusion) 上で正常動作するか~~ → **2026-03-24 タスク1-1で確認済み**（aarch64, apk-tools 2.14.6, mariadbd 11.4.8-MariaDB）
- [ ] penultimate stable version の解釈（3.21 で正しいか、レビュアーとの認識合わせ）

---

## 参考実装との比較

| 項目 | 参考実装 (Vagrant_sample) | 自分の実装（予定） |
|------|--------------------------|-------------------|
| ベースイメージ | Alpine 3.22 | **Alpine 3.21** |
| VM provider | VirtualBox | VMware Fusion（→後で VirtualBox に移植）|
| secrets | 未使用 | **Docker compose secrets** |
| MariaDB 待機 | `until mariadb-admin ping` (WordPress側) | **ping ループ + タイムアウト** (WordPress側) |
| 初期化ガード | なし（SQL の IF NOT EXISTS のみ） | **`if [ ! -d ... ]` による明示ガード + IF NOT EXISTS** |
| 起動順制御 | `depends_on` のみ | **`depends_on` + `healthcheck` + `condition: service_healthy`** |
| CMD/ENTRYPOINT | `ENTRYPOINT` | `ENTRYPOINT`（CMD から変更） |
| PHP-FPM ユーザー | nobody | 検討中（nobody or 専用ユーザー） |
| ドメイン | takitaga.42.fr | toruinoue.42.fr |
| データパス | /home/takitaga/data/ | /home/toruinoue/data/ |

---

## バックアップ一覧

| ファイル | 場所 | 内容 |
|---------|------|------|
| `backup_mariadb_Dockerfile_debian_v1` | `dev_docs/` | Debian 版 MariaDB Dockerfile |
| `backup_mariadb_init_sh_debian_v1` | `dev_docs/` | Debian 版 MariaDB init.sh |
