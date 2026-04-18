# 学習メモ: nginx の `index`、FastCGI、Docker volume の関係（2026-04-14）

> 自己学習用。課題タスク番号には紐づけない。  
> 出典: チャットでの質疑（`torinoue_nginx.conf`・手動 `docker run`・`docker-compose.yml` の整理）。

---

## 1. `index index.php index.html;` は何をしているか

- **役割**: リクエスト URI が**ディレクトリ**（末尾 `/` や「ファイル名なし」）のとき、**既定で返すファイル名の候補**を、**左から順に**試す。
- **例**: `index.php` を先に書くのは、WordPress のように PHP が入口のサイトでは一般的。

一次資料: [nginx `index` 指令](https://nginx.org/en/docs/http/ngx_http_index_module.html#index)

---

## 2. nginx コンテナ内に `index.php` は「ある」のか

- **イメージのレイヤーだけ**見ると、nginx の Dockerfile に WordPress を COPY していなければ **`index.php` は同梱されない**ことが多い。
- **実行時**に `index.php` が「nginx から見えるか」は、**名前付きボリュームや bind mount で `/var/www/html` を WordPress と共有しているか**で決まる。
- **設定ファイルだけ**では「nginx のディスク上にあるか」は断定できない。**確認する**なら例:

  ```bash
  docker exec nginx ls -la /var/www/html
  docker exec nginx test -f /var/www/html/index.php && echo yes || echo no
  ```

---

## 3. Docker の volume 設定は「どのファイル」か

- **Compose を使う場合**: 通常は **`srcs/docker-compose.yml`** の各サービス `volumes:` と、トップレベル `volumes:` で名前付きボリュームを宣言する。
- **手動 `docker run` のみ**の場合: セッションログのように **`-v` が無ければ、そのコマンド列では volume は付いていない**（永続化・共有は compose 側の記述だけでは自動では効かない）。

---

## 4. 手動 RUN＋ネットワークだけでも「ブログ更新」ができる理由

- **名前付きボリュームは「動かすため」に必須ではない**。主な用途は **コンテナ削除後もデータを残す**こと、**複数コンテナで同じディレクトリを共有する**こと。
- 投稿の保存などは **MariaDB への書き込み**であり、WordPress コンテナが **`mariadb` ホスト名で DB に接続**できれば成立する（同一ユーザ定義ネットワーク上）。
- WordPress の PHP ファイルは **wordpress コンテナ内の `/var/www/html`** に置かれる想定で、**コンテナを消さない限り**その中に残る。
- まとめ: **「ネットワークで繋がっている」＋各コンテナ内に DB／ファイルがある**だけで、compose や `-v` なしでも**一時的な動作確認**は可能。volume は **永続化・共有**のレイヤ。

---

## 5. `location ~ \.php$` と `fastcgi_pass wordpress:9000` は「丸投げ」か

- **意味**: PHP リクエストの実行は **WordPress コンテナの PHP-FPM（例: ポート 9000）** に渡す、という**役割分担**。
- **重要**: `fastcgi_pass` は **nginx に `index.php` をコピーする仕組みではない**。  
  nginx は `SCRIPT_FILENAME` などとして **パス文字列**を渡し、**実際にファイルを開いて実行するのは PHP-FPM 側**（WordPress コンテナのファイルシステム）。
- そのため **`$document_root` が `/var/www/html` で揃っていれば**、nginx 側ディスクにファイルが無くても、**WordPress 側に `/var/www/html/index.php` があれば**動く、という説明がつく。
- **本当に nginx コンテナのディスク上にも同じファイルを置きたい**場合は、**共有ボリューム**や **イメージへの COPY** など、**ストレージ側の設計**の話になる（FastCGI の設定だけでは足りない）。

一次資料（入口）: [nginx FastCGI モジュール](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)

---

## 6. 自分用チェックリスト

| 疑問 | 整理 |
|------|------|
| `index` は必須？ | ディレクトリ URI の既定ファイルを決める。WP なら `index.php` 優先が多い。 |
| nginx に `index.php` が要る？ | PHP の実体は FPM 側。**共有 volume で揃えるか**は設計次第。 |
| volume が無いと更新できない？ | **コンテナ生存中**は DB／WP 内に書ける。消したときに残るかが問題。 |
| `fastcgi_pass` でファイルが nginx に現れる？ | **しない**。実行は WordPress 側。 |

---

## 参考（リポジトリ内）

- `srcs/requirements/nginx/conf/torinoue_nginx.conf` — `root` / `index` / `try_files` / `fastcgi_pass`
- `session_logs/0021_session_log_inception.md` — 手動 `docker run`・`test-net` の再現手順
