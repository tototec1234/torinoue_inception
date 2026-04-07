# Inception レビュー対策ノート - NGINX 編（フェーズ2 事後）

> 対応フェーズ: 2  
> 参照セッション: `session_logs/0010_session_log_inception.md`（タスク 2-5）、`session_logs/0011_session_log_inception.md`（タスク 2-6）  
> 備考: `0200_nginx_pre_quiz_inception.md` の論点（TLS の一般定義、`ssl_protocols` の教科書的説明、`try_files` の一般論など）は**再掲していません**。設問は上記セッションで得た実験知に寄せています。

---

## Q1. `host not found in upstream` が出たときの原因（選択）

**状況**: `fastcgi_pass wordpress:9000;` を含む `nginx.conf` でビルドしたイメージを、`docker run` で**単独コンテナ**（デフォルトブリッジのみ、他コンテナなし）として起動したところ、nginx が **`[emerg] host not found in upstream "wordpress:9000"`** で終了した。

このとき、最も適切な説明はどれか。

- A. TLS 証明書の CN が `wordpress` と一致しないため  
- B. `wordpress` という名前が **Docker の埋め込み DNS で解決できるコンテナ**がネットワーク上に存在しないため  
- C. MariaDB が起動していないため  
- D. 443 番ポートが他プロセスに奪われているため  

**自分の回答：**
（ここに記入）

**正解：**
B

**解説：**
`fastcgi_pass` にホスト名を書いた場合、nginx は設定読み込み時（起動時）にその名前を **名前解決**しようとすることが多い。ユーザ定義ブリッジネットワーク上では **コンテナ名が DNS 名**として解決されるが、**同名のコンテナが存在しない**、または **同一ユーザ定義ネットワークに参加していない**と解決に失敗し、`host not found in upstream` となる。TLS の CN や MariaDB の有無は、このエラーメッセージの直接原因ではない。

**一次資料：**
- [nginx `fastcgi_pass` ドキュメント](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_pass)（upstream の指定）
- [Docker Networking overview — User-defined networks](https://docs.docker.com/network/drivers/bridge/#differences-between-user-defined-bridges-and-the-default-bridge)（コンテナ名と DNS）

---

## Q2. タスク 2-5 の「方針 A」の目的（記述）

**質問:**  
セッションログ 0010 にある **方針 A**（イメージ単体＋最小限の外部）を、**何を満たすための割り切り**として採用したか、2〜4 文で説明してください。  
（キーワード例: `fastcgi_pass`、`wordpress`、ユーザ定義ネットワーク、DNS）

**自分の回答：**
（ここに記入）

**正解：**
課題用 `nginx.conf` を **`fastcgi_pass wordpress:9000;` のまま**変えずにテストするために、**ユーザ定義ブリッジネットワーク上にコンテナ名 `wordpress` を持つスタブ**を置き、nginx が起動時に `wordpress` を **Docker の埋め込み DNS で解決できる状態**にする、という割り切り。これにより **`host not found in upstream`** を避け、**TLS・443 の単体疎通**（`curl` で TLS ネゴシエーションと応答確認）に集中できる。

**解説：**
「単体」テストでも、設定ファイルに書かれた upstream 名の解決は必要になりうる。方針 A は **PHP-FPM の実装を揃える前**に、**名前解決だけ** Docker に任せる最小構成として合理的である（スタブは `sleep infinity` 等でよい、というログ上の前提）。

**一次資料：**
- `session_logs/0010_session_log_inception.md`（方針 A の定義）
- [Docker Embedded DNS](https://docs.docker.com/network/drivers/bridge/#embedded-dns-server)（同一ネットワーク内の名前解決）

---

## Q3. TLS は成功したのに HTTP が 502 になる理由（選択）

**状況**: タスク 2-5 の PoC と同様、`wordpress` コンテナは **Alpine のスタブ**（`sleep infinity`）のみ。`/` にアクセスすると **`502 Bad Gateway`**、`curl -v` では **`SSL connection using TLSv1.3`** は確認できた。

この 502 の主因として最も適切なものはどれか。

- A. 自己署名証明書をブラウザが拒否したため  
- B. **`/` のリクエストが PHP 経由の処理（`fastcgi_pass`）に流れ、スタブ側に PHP-FPM が Listen していない**ため  
- C. `ssl_protocols` に TLSv1.3 が含まれていないため  
- D. MariaDB が停止しているため  

**自分の回答：**
（ここに記入）

**正解：**
B

**解説：**
**TLS ハンドシェイク**はクライアントと nginx の間で完結する。ログのとおり TLSv1.3 が成立していれば、暗号化レイヤは成功している。その後、nginx が **FastCGI で上流（`wordpress:9000`）に接続**しようとしても、スタブは **9000 で待ち受けていない**ため、上流へのプロキシが失敗し **502** になりやすい。自己署名は検証警告の原因になりうるが、ここでは `--insecure` 前提で TLS 層は成功している。MariaDB はこのリクエストパスでは主因にならない。

**一次資料：**
- [MDN — HTTP 502 Bad Gateway](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/502)（ゲートウェイ・プロキシが無効な応答を受けた場合)
- [nginx `ngx_http_fastcgi_module`](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)

---

## Q4. 「2-5 の合格ライン」として TLS だけ見る判断（記述）

**質問:**  
0010 の PoC では **`502 Bad Gateway`** でも、タスク 2-5 の主目的（TLS・443）は達成とした。なぜ **HTTP ステータスが 200 でなくても**よいと言えるのか、設定とリクエストパス（`/`）の関係に触れて説明してください。

**自分の回答：**
（ここに記入）

**正解：**
タスク 2-5 のスコープを **TLS・443・証明書・プロトコル交渉**に限定しているため。`/` へのアクセスは設定次第で **`index.php` 等へフォールバックし FastCGI に流れる**ことがあり、スタブ環境では **502 になりうる**。それでも **TLS レイヤが張れている**ことは `curl -v` の `SSL connection using TLSv1.3` 等で確認できるので、**フェーズ目標（TLS 単体）**は満たしうる。静的 HTML で 200 を出す検証は 2-6 の範囲として切り分けられる。

**解説：**
「単体テストで何をもって合格とするか」をスコープで固定することが重要。502 は **アプリケーション上流未到達**のシグナルであり、TLS 失敗とは別問題として切り分けられる。

**一次資料：**
- `session_logs/0010_session_log_inception.md`（PoC 判定・502 の位置づけ）

---

## Q5. ユーザ定義ネットワークを作る理由（選択）

**質問:**  
`docker network create inception-test-net` のような **ユーザ定義ブリッジ**を使う主な理由として、セッション手順と整合する説明はどれか。

- A. デフォルトブリッジでは **コンテナ名による自動 DNS が使えない**（ユーザ定義では使える）  
- B. TLSv1.3 を有効にするため  
- C. MariaDB のデータを永続化するため  
- D. イメージサイズを小さくするため  

**自分の回答：**
（ここに記入）

**正解：**
A

**解説：**
**デフォルトの `bridge` ネットワーク**では、コンテナ間の名前解決は **リンク（レガシー）や手動の `--link` に依存しがち**で、現代的な **コンテナ名ベースの埋め込み DNS** は **ユーザ定義ネットワーク**で期待どおり動かしやすい（公式ドキュメントでもユーザ定義ブリッジの利用が推奨される）。実験手順では `wordpress` を名前で引く必要がある。

**一次資料：**
- [Docker — Differences between user-defined bridges and the default bridge](https://docs.docker.com/network/drivers/bridge/#differences-between-user-defined-bridges-and-the-default-bridge)

---

## Q6. `curl --insecure` の役割（選択）

**質問:**  
自己署名証明書で HTTPS にアクセスするとき `curl --insecure`（`-k`）を付けたのはなぜか。最も適切なものはどれか。

- A. TLSv1.3 を強制するため  
- B. **サーバ証明書の検証をスキップ**し、信頼されていない自己署名でも接続・応答本文を確認するため  
- C. HTTP/2 を有効にするため  
- D. Basic 認証を省略するため  

**自分の回答：**
（ここに記入）

**正解：**
B

**解説：**
自己署名証明書は OS や curl のデフォルトの **信頼ストアに含まれない**ため、通常は証明書エラーで失敗する。`--insecure` は **暗号化そのものを無効化する**のではなく、**相手先の身元確認（検証）を行わない**オプション。開発・検証で TLS ハンドシェイクと応答を見る用途に使われる。

**一次資料：**
- [curl man page — `-k, --insecure`](https://curl.se/docs/manpage.html#-k)

---

## Q7. 既存コンテナを後からネットワークに参加させる（記述）

**質問:**  
0011 では、先に `docker run` で起動済みの `mariadb` コンテナを **`inception-test-net` に接続**した。使ったコマンドの形と、**なぜ `docker run` 時に `--network` だけでは足りない場合があるのか**を簡潔に述べよ。

**自分の回答：**
（ここに記入）

**正解：**
**`docker network connect inception-test-net mariadb`** のように、**既存コンテナを既存ネットワークに追加**する。MariaDB を先に **単体起動**（ネットワーク未指定や別ネットワーク）しており、後から NGINX・`wordpress` と **同一のユーザ定義ネットワーク**に載せたいとき、**起動済みコンテナのネットワークは `connect` で追加**する。

**解説：**
`docker run --network` は **起動時の主所属**を決める。既に動いているコンテナに **第二のネットワーク面**を足すのが `network connect` である（切断は `network disconnect`）。

**一次資料：**
- [docker network connect](https://docs.docker.com/reference/cli/docker/network/connect/)

---

## Q8. `index.html` で 200 になったが `/` は 502 になりうる（記述）

**質問:**  
0011 の手順では **`https://127.0.0.1/index.html`** で **200 OK** を確認した。同じコンテナ・同じスタブ環境で **`https://127.0.0.1/`**（パス `/`）にアクセスすると **502** になりうる。なぜか、**リクエストがどの `location`・どの処理（静的 vs FastCGI）に流れるか**の観点で説明せよ（設定の一般的パターンに依拠してよい）。

**自分の回答：**
（ここに記入）

**正解：**
`/index.html` は **拡張子付きのパス**として **静的ファイル**（`root` 以下）にマッチし、ファイルが存在すれば nginx が直接返せる。一方 `/` は **`try_files` や `index` ディレクティブ**により **`index.php` 等へフォールバック**し、**`location ~ \.php$` などで FastCGI** に流れる構成が多い。その結果、スタブ環境では **FastCGI 先に接続できず 502** になりうる。つまり **同じサーバでもパスによって静的配信と PHP 経由が切り替わる**。

**解説：**
この問は **事前クイズの `try_files` 定義の暗記**ではなく、**実験で見た「index.html は手動配置で 200」「ルートは別」**を説明できるかを見る。

**一次資料：**
- [nginx `try_files`](https://nginx.org/en/docs/http/ngx_http_core_module.html#try_files)
- [nginx `location` 優先順位](https://nginx.org/en/docs/http/ngx_http_core_module.html#location)

---

## Q9. `/var/www/html` を `mkdir -p` した理由（選択）

**質問:**  
0011 で `docker exec nginx-task26 mkdir -p /var/www/html` が必要だった。0011 の「未解決事項」にもあるが、考えられる理由として最も近いものはどれか。

- A. TLS 証明書を置くため  
- B. **ビルドした NGINX イメージに、配信先ディレクトリが存在しない**ため  
- C. MariaDB のソケットファイルを置くため  
- D. `docker network create` の副作用を消すため  

**自分の回答：**
（ここに記入）

**正解：**
B

**解説：**
Alpine ベースの最小イメージでは、`root` で指定した **`/var/www/html` が Dockerfile で作成されていない**場合がある。ディレクトリが無いと静的ファイルを配置できないため、実行時に `mkdir -p` するか、**Dockerfile で `RUN mkdir -p`** しておくのが定石。本番統合ではボリュームや WordPress 側でパスが揃う想定もある。

**一次資料：**
- [nginx `root` ディレクティブ](https://nginx.org/en/docs/http/ngx_http_core_module.html#root)

---

## Q10. `wpuser@'%'` なのに `mariadb-admin ping -u wpuser` が失敗する理由（選択）

**質問:**  
`CREATE USER 'wpuser'@'%' ...` でユーザーを作っているのに、コンテナ内で次が失敗した。

```text
docker exec mariadb mariadb-admin ping -u wpuser -pwppassword
# Access denied for user 'wpuser'@'localhost'
```

最も適切な説明はどれか。

- A. パスワードが `entrypoint.sh` と不一致だから  
- B. **`'%'` は TCP 接続元ホストにマッチするが、`localhost` 省略時の UNIX ソケット接続では `wpuser@'localhost'` が必要**で、後者のユーザがいないから  
- C. MariaDB が TCP を無効化しているから  
- D. NGINX が 443 で遮断しているから  

**自分の回答：**
（ここに記入）

**正解：**
B

**解説：**
MariaDB/MySQL は **ユーザー名と接続元ホストの組**で認証する。`'%'` は **リモート（TCP）からの接続元**としてマッチするが、**`localhost` にデフォルトで繋ぐクライアントは UNIX ドメインソケット**を使い、認証上は **`'wpuser'@'localhost'`** を探す。該当ユーザが無ければ拒否される。WordPress コンテナから **`mariadb` ホスト名で TCP** すれば `'%'` が効く、という整理（0011 Spike と同じ）。

**一次資料：**
- [MariaDB KB — CREATE USER](https://mariadb.com/kb/en/create-user/)
- [MariaDB KB — How MariaDB authenticates connections](https://mariadb.com/kb/en/how-mariadb-authenticates-clients/)（接続方法と host の関係）

---

## Q11. レビューで「wpuser で ping が通らないのは？」と聞かれたとき（記述）

**質問:**  
0011 の Spike を踏まえ、**Inception では WordPress からの DB 接続に問題がない**ことを一言でどう説明するか（2〜3 文）。

**自分の回答：**
（ここに記入）

**正解：**
WordPress は **`DB_HOST=mariadb` のようなホスト名で TCP 接続**する。`wpuser@'%'` は **TCP の接続元**にマッチする。問題になったのは **同一コンテナ内で `localhost`（ソケット）として `wpuser` で繋いだ**ケースであり、**アプリ経路とは別**である。

**解説：**
レビューでは **「テスト方法と本番経路の違い」**を言語化できると高評価になりやすい。

**一次資料：**
- `session_logs/0011_session_log_inception.md`（Spike 記録）

---

## Q12. `mariadb-admin ping` を root で行う意味（選択）

**質問:**  
0011 の手順では **`docker exec mariadb mariadb-admin ping`**（ユーザ指定なし）で生存確認した。これが妥当な理由として最も近いものはどれか。

- A. root の方が ping が速いから  
- B. **デフォルトはソケット接続で管理者（root）が許可されており、DB 生存確認に十分だから**  
- C. wpuser はセキュリティ上削除済みだから  
- D. TLS クライアント証明書が必要だから  

**自分の回答：**
（ここに記入）

**正解：**
B

**解説：**
`mariadb-admin ping` は **サーバプロセスが応答するか**を見るコマンドで、**UNIX ソケット経由の root（またはソケット認証が通るユーザ）**で足りることが多い。アプリユーザ `wpuser` の **TCP 経路での接続テスト**は別コマンド（`mariadb -h mariadb -u wpuser -p` 等）で行う、と役割を分ける。

**一次資料：**
- [MariaDB Admin — mariadb-admin](https://mariadb.com/kb/en/mariadb-admin/)

---

## Q13. 3 コンテナを同一ネットワークに載せる目的（記述）

**質問:**  
0011 で **MariaDB・wordpress スタブ・nginx** を **`inception-test-net` に同居**させた。NGINX が MariaDB に直接 SQL を投げるわけではないが、**同一ユーザ定義ネットワークに載せる意義**を、将来の compose 統合にもつなげて簡潔に述べよ。

**自分の回答：**
（ここに記入）

**正解：**
**コンテナ間の名前解決と到達性**を、ホストのポート公開に依存せずに検証するため。NGINX→WordPress（FastCGI）、WordPress→MariaDB（3306）など **サービス名／コンテナ名で相互参照**する構成に近い形で、**ネットワーク分離と DNS** の振る舞いを先に確認できる。compose では同様に **同一ネットワーク上のサービス名**が使われる。

**解説：**
「nginx が DB に触らないのになぜ同じ net？」はよくある誤解。**統合テストでは複数役割の同居と名前解決**を一度に確かめる意味がある。

**一次資料：**
- [Docker Compose networking](https://docs.docker.com/compose/how-tos/networking/)（サービス名解決のイメージ）

---

## 今日詰まったポイント（実装メモ）

（ドライバー記入用のプロンプト）

- 502 が出た／出なかったパスと、そのとき **静的か FastCGIか** の対応づけ:
- `docker network` と **`connect` / `disconnect`** でハマった点:
- **`wpuser` / `root` / `localhost` / TCP** のどこで認識がずれたか:
- 次に Dockerfile / compose に戻すときの **TODO 一行**:

---

## レビュー想定問答集（弱点中心）

（ドライバー記入用のプロンプト）

- **「TLS は通ったのに 502 は何が悪い？」** に対する自分の一文:
- **`host not found in upstream` をどう再現し、どう直したか**（手順ベース）:
- **`wpuser@'%'` とソケット**の説明を口頭で30秒:
- **ユーザ定義ブリッジを使う理由**を他コンテナ名とセットで:
- 想定外の追撃質問と、そのときの答え（未整理でも可）:

---

## 付記（運用）

- **自分の回答**をすべて埋めたら、このファイルをチャットに貼り、Navigator に **正解・解説の添削**を依頼できる（既に本文に正解・解説がある場合は、**自分の回答との差分**を中心にレビューしてもらう）。
- `phase_plan.md` の「フェーズ2 事後クイズ」完了チェックは、**ドライバー確認のうえ**で `[x]` にすること。
