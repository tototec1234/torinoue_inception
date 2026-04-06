# Inception レビュー対策ノート - NGINX 編（フェーズ2 事後）

> 対応フェーズ: 2  
> 参照セッション: `session_logs/0010_session_log_inception.md`（タスク 2-5）、`session_logs/0011_session_log_inception.md`（タスク 2-6）  
> 備考: `0200_nginx_pre_quiz_inception.md` の論点（TLS の一般定義、`ssl_protocols` の教科書的説明、`try_files` の一般論など）は**再掲していません**。設問は上記セッションで得た実験知に寄せています。
> 採点日: 2026-04-04  
> 結果: 選択式 7/7、記述式 2 ほぼ正解・3 部分正解・1 不正解

---

## Q1. `host not found in upstream` が出たときの原因（選択）

**状況**: `fastcgi_pass wordpress:9000;` を含む `nginx.conf` でビルドしたイメージを、`docker run` で**単独コンテナ**（デフォルトブリッジのみ、他コンテナなし）として起動したところ、nginx が **`[emerg] host not found in upstream "wordpress:9000"`** で終了した。

このとき、最も適切な説明はどれか。

- A. TLS 証明書の CN が `wordpress` と一致しないため  
- B. `wordpress` という名前が **Docker の埋め込み DNS で解決できるコンテナ**がネットワーク上に存在しないため  
- C. MariaDB が起動していないため  
- D. 443 番ポートが他プロセスに奪われているため  

**自分の回答：**

B.

**正解：** B ✅

**解説：**
`fastcgi_pass` にホスト名を書いた場合、nginx は設定読み込み時（起動時）にその名前を **名前解決**しようとする。ユーザ定義ブリッジネットワーク上では **コンテナ名が DNS 名**として解決されるが、**同名のコンテナが存在しない**、または **同一ユーザ定義ネットワークに参加していない**と解決に失敗し、`host not found in upstream` となる。TLS の CN や MariaDB の有無は、このエラーメッセージの直接原因ではない。

**一次資料：**
- [nginx `fastcgi_pass` ドキュメント](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_pass)（upstream の指定）
- [Docker Networking overview — User-defined networks](https://docs.docker.com/network/drivers/bridge/#differences-between-user-defined-bridges-and-the-default-bridge)（コンテナ名と DNS）

---

## Q2. タスク 2-5 の「方針 A」の目的（記述）

**質問:**  
セッションログ 0010 にある **方針 A**（イメージ単体＋最小限の外部）を、**何を満たすための割り切り**として採用したか、2〜4 文で説明してください。  
（キーワード例: `fastcgi_pass`、`wordpress`、ユーザ定義ネットワーク、DNS）

**自分の回答：**

1) ブラウザとnginxの間でTLS 1.2 またはTLS 1.3のみで疎通・TLS 確認通信可能
2) ユーザー定義ネットワークを構築してDockerのDNSが名前解決可能
3) nginxコンテナ内に存在しないページへのリクエストに対しnginxがwordpressに投げる
の3点をテストする条件を満たす割り切りとして方針Aを採用した。
具体的にはnginxとWordPress/PHP-FPM との通信についてはWordPressの実装後にテストすれば良いと割り切り、nginxのconfに手を加えずに、スタブとしてalpineのイメージをwordpressという「名前」でRUNさせてテストした。

**正解：** ほぼ正解 ✅

課題用 `nginx.conf` を **`fastcgi_pass wordpress:9000;` のまま変えずに**テストするために、**ユーザ定義ブリッジネットワーク上にコンテナ名 `wordpress` を持つスタブ**を置き、nginx が起動時に `wordpress` を **Docker の埋め込み DNS で解決できる状態**にする、という割り切り。これにより **`host not found in upstream`** を避け、**TLS・443 の単体疎通**に集中できる。

**解説：**
回答の 1) 2) と後半段落は正確。ただし 3)「nginx が wordpress に投げる」は方針 A の **目的** というより **観察された挙動**（結果として 502 になる）。方針 A の核心は **「conf を変えずに名前解決だけ満たし、TLS テストに集中する」** という割り切り。「単体」テストでも upstream 名の解決は必要になりうる、という教訓が背景にある。

**一次資料：**
- `session_logs/0010_session_log_inception.md`（方針 A の定義）
- [Docker Embedded DNS](https://docs.docker.com/network/drivers/bridge/#embedded-dns-server)（同一ネットワーク内の名前解決）

---

## Q3. TLS は成功したのに HTTP が 502 になる理由（選択）

**状況**: タスク 2-5 の PoC と同様、`wordpress` コンテナは **Alpine のスタブ**（`sleep infinity`）のみ。`/` にアクセスすると **`502 Bad Gateway`**、`curl -v` では **`SSL connection using TLSv1.3`** は確認できた。

この 502 の主因として最も適切なものはどれか。

- A. 自己署名証明書をブラウザが拒否したため  
- B. `/` のリクエストが PHP 経由の処理（`fastcgi_pass`）に流れ、スタブ側に PHP-FPM が Listen していないため  
- C. `ssl_protocols` に TLSv1.3 が含まれていないため  
- D. MariaDB が停止しているため  

**自分の回答：**
B. なお、A.については署名証明書検証をスキップさせる`curl --insecure --verbose https://127.0.0.1/index.html`でも結果に差がないため論点外。

**正解：** B ✅

**解説：**
**TLS ハンドシェイク**はクライアントと nginx の間で完結する。TLSv1.3 が成立していれば暗号化レイヤは成功している。その後、nginx が **FastCGI で上流（`wordpress:9000`）に接続**しようとしても、スタブは **9000 で待ち受けていない**ため、上流へのプロキシが失敗し **502** になる。回答の A に対する補足（`--insecure` で検証スキップしても結果が同じ → 証明書の問題ではない）は的確な切り分け。

**一次資料：**
- [MDN — HTTP 502 Bad Gateway](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/502)（ゲートウェイ・プロキシが無効な応答を受けた場合)
- [nginx `ngx_http_fastcgi_module`](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)

---

## Q4. 「2-5 の合格ライン」として TLS だけ見る判断（記述）

**質問:**  
0010 の PoC では **`502 Bad Gateway`** でも、タスク 2-5 の主目的（TLS・443）は達成とした。なぜ **HTTP ステータスが 200 でなくても**よいと言えるのか、設定とリクエストパス（`/`）の関係に触れて説明してください。

**自分の回答：**
```nginx
		location / {
			try_files $uri $uri/ /index.php?$args;
		}
```
- リクエストを`/`で受け取ったあと$uri（存在しない）→ $uri/（存在しない）→ 最終的に /index.php?$args へ内部転送
- try_files の行き先である index.php（バックエンドwordpress/PHP-FPM）との通信を試みるも、スタブは無反応なのでnginxは502をフロントエンドに返す
- 内部転送をしていることが確認できたのでOK

**正解：** 部分正解 ⚠️

タスク 2-5 のスコープを **TLS・443・証明書・プロトコル交渉に限定**しているため。`/` へのアクセスは `try_files` により `index.php` へフォールバックし FastCGI に流れるが、スタブ環境では **502 になりうる**。それでも **TLS レイヤが張れている**ことは `curl -v` の `SSL connection using TLSv1.3` で確認できるので、**フェーズ目標（TLS 単体）は満たしている**。静的 HTML で 200 を出す検証は 2-6 の範囲として切り分けられる。

**解説：**
`try_files` の連鎖メカニズムの説明は正確。ただし設問が聞いているのは **「なぜ 200 でなくてもよいか」** であり、その答えは **「タスク 2-5 のスコープが TLS・443 に限定されているから」**。「内部転送が確認できたのでOK」は方針 A の合格判定基準とは少しずれる — 502 は内部転送の確認手段ではなく、**上流未到達の副産物**。合格の根拠は「`curl -v` で TLSv1.3 のネゴシエーションが成立したこと」に置く。

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

A.

**正解：** A ✅

**解説：**
**デフォルトの `bridge` ネットワーク**では、コンテナ間の名前解決は **レガシーの `--link`** に依存しがちで、**コンテナ名ベースの埋め込み DNS** は **ユーザ定義ネットワーク**で使える（公式ドキュメントでもユーザ定義ブリッジの利用が推奨される）。実験手順では `wordpress` を名前で引く必要があるため必須だった。

**一次資料：**
- [Docker — Differences between user-defined bridges and the default bridge](https://docs.docker.com/network/drivers/bridge/#differences-between-user-defined-bridges-and-the-default-bridge)

---

## Q6. `curl --insecure` の役割（選択）

**質問:**  
自己署名証明書で HTTPS にアクセスするとき `curl --insecure`（`-k`）を付けたのはなぜか。最も適切なものはどれか。

- A. TLSv1.3 を強制するため  
- B. サーバ証明書の検証をスキップし、信頼されていない自己署名でも接続・応答本文を確認するため  
- C. HTTP/2 を有効にするため  
- D. Basic 認証を省略するため  

**自分の回答：**
B.

- `--insecure`なしだと
	```bash
	* TLSv1.3 (OUT), TLS alert, unknown CA (560):
	* SSL certificate problem: self-signed certificate
	* Closing connection 0
	```
	`unknown CA` → 「この証明書を発行したCAを知らない」→ 接続拒否
	- ありだと
	```bash
	*  SSL certificate verify result: self-signed certificate (18), continuing anyway.
	```
	`continuing anyway` → 警告は出るが続行

**正解：** B ✅

**解説：**
自己署名証明書は OS や curl のデフォルトの **信頼ストアに含まれない**ため、通常は証明書エラーで失敗する。`--insecure` は **暗号化そのものを無効化する**のではなく、**相手先の身元確認（検証）を行わない**オプション。回答に添えられた実際の `curl` 出力の比較（`unknown CA` → 接続拒否 vs `continuing anyway` → 続行）は、挙動の違いを実証として示しており非常に良い。

**一次資料：**
- [curl man page — `-k, --insecure`](https://curl.se/docs/manpage.html#-k)

---

## Q7. 既存コンテナを後からネットワークに参加させる（記述）

**質問:**  
0011 では、先に `docker run` で起動済みの `mariadb` コンテナを **`inception-test-net` に接続**した。使ったコマンドの形と、**なぜ `docker run` 時に `--network` だけでは足りない場合があるのか**を簡潔に述べよ。

**自分の回答：**
```bash
docker network create inception-test-net
docker network connect inception-test-net mariadb
```
```bash
docker run -d --name nginx-task26 \
  -p 443:443 \
  --network inception-test-net \
  nginx-test:task26
```
主な理由は以下の2点です。
ネットワークの「リフレッシュ」: docker run 時の自動割り当てで通信が不安定（IPやルーティングの不整合）になった場合、手動で connect し直すことで、ネットワークインターフェースやDNS登録が物理的に初期化・再構築され、正常な疎通が確立されるため。
複数ネットワークへの所属: docker run --network では1つのネットワークにしか参加できません。コンテナを複数のネットワーク（例：DB用と外部通信用）に同時に接続したい場合は、後から docker network connect で追加する必要があります。

**正解：** 部分正解 ⚠️

**`docker network connect inception-test-net mariadb`** で、**既存コンテナを既存ネットワークに追加**する。`docker run --network` は **コンテナ作成時** にしか指定できない。MariaDB を先に単体起動（ネットワーク未指定 or デフォルトブリッジ）しており、後から NGINX・`wordpress` と **同一のユーザ定義ネットワーク**に載せたいとき、**起動済みコンテナには `connect` で追加**する。

**解説：**
コマンド例は正確。2点目の「複数ネットワークへの所属」は正しい — `docker run --network` は1つのみで、追加は `connect` が必要。

ただし1点目の「リフレッシュ」は根拠のない説明。Docker のユーザ定義ネットワークで IP やルーティングの不整合が通常発生するわけではなく、`connect` し直すことで「リフレッシュ」するという挙動は公式ドキュメントに記載がない。**0011 で `connect` を使った直接の理由**は、MariaDB コンテナが **`inception-test-net` 作成前に既に起動していた**（`docker run` 時にはまだネットワークが存在しなかった）ため。

**一次資料：**
- [docker network connect](https://docs.docker.com/reference/cli/docker/network/connect/)

---

## Q8. `index.html` で 200 になったが `/` は 502 になりうる（記述）

**質問:**  
0011 の手順では **`https://127.0.0.1/index.html`** で **200 OK** を確認した。同じコンテナ・同じスタブ環境で **`https://127.0.0.1/`**（パス `/`）にアクセスすると **502** になりうる。なぜか、**リクエストがどの `location`・どの処理（静的 vs FastCGI）に流れるか**の観点で説明せよ（設定の一般的パターンに依拠してよい）。

**自分の回答：**

`https://127.0.0.1/index.html`ではあらかじめnginx内のコンテナに作成したページをリクエストしている。あらかじめ作成されているファイルは静的ページなので　200OKとなる。
一方`https://127.0.0.1/`はルートディレクトのみ指定なので、 FastCGIに流れ`/index.php`で動的なページ生成をwordpressに丸投げするが、スタブは応じないので「投げる先が間違っている」となる

**正解：** ほぼ正解 ✅

`/index.html` は **拡張子付きの静的ファイルパス**として `root` 以下にマッチし、ファイルが存在すれば nginx が直接返す。一方 `/` は **`try_files` や `index` ディレクティブ**により `index.php` へフォールバックし、**`location ~ \.php$` で FastCGI** に流れる。スタブ環境では FastCGI 先に接続できず **502** になる。

**解説：**
静的 vs FastCGI の切り分けは正確に理解できている。1点だけ: 「投げる先が間違っている」という表現は不正確。502 Bad Gateway は **「上流（upstream）が存在するが、有効な応答を返さなかった」** というステータス。投げる先（`wordpress:9000`）は設定上正しいが、**スタブが 9000 番ポートで Listen していない** ため応答が返らない。「先が間違っている」のではなく「先がいない（応答しない）」。

**一次資料：**
- [nginx `try_files`](https://nginx.org/en/docs/http/ngx_http_core_module.html#try_files)
- [nginx `location` 優先順位](https://nginx.org/en/docs/http/ngx_http_core_module.html#location)

---

## Q9. `/var/www/html` を `mkdir -p` した理由（選択）

**質問:**  
0011 で `docker exec nginx-task26 mkdir -p /var/www/html` が必要だった。0011 の「未解決事項」にもあるが、考えられる理由として最も近いものはどれか。

- A. TLS 証明書を置くため  
- B. ビルドした NGINX イメージに、配信先ディレクトリが存在しないため  
- C. MariaDB のソケットファイルを置くため  
- D. `docker network create` の副作用を消すため  

**自分の回答：**
B.

**正解：** B ✅

**解説：**
Alpine ベースの最小イメージでは、`nginx.conf` の `root` で指定した **`/var/www/html` が Dockerfile で作成されていない**場合がある。ディレクトリが無いと静的ファイルを配置できないため、実行時に `mkdir -p` するか、**Dockerfile で `RUN mkdir -p`** しておくのが定石。本番統合ではボリュームマウントや WordPress 側でパスが揃う想定もある（0011 の未解決事項に記録済み）。

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
- B. `'%'` は TCP 接続元ホストにマッチするが、`localhost` 省略時の UNIX ソケット接続では `wpuser@'localhost'` が必要で、後者のユーザがいないから  
- C. MariaDB が TCP を無効化しているから  
- D. NGINX が 443 で遮断しているから  

**自分の回答：**
B.
なお`docker exec mariadb mariadb-admin ping -u wpuser`と`-pwppassword`を省けばコンテナのユーザー名（OSのユーザー名）とDBのユーザー名が一致していればunix_socket 認証でpingが通る。
entrypoint.shを下記に変更がベストなのかも？
```bash
-- どこからでも接続できるようにする（WordPressコンテナ用）
CREATE USER IF NOT EXISTS 'wpuser'@'%' IDENTIFIED BY 'wppassword';
GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wpuser'@'%';

-- コンテナ内（mariadb-admin用）からも接続できるようにする
CREATE USER IF NOT EXISTS 'wpuser'@'localhost' IDENTIFIED BY 'wppassword';
GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wpuser'@'localhost';

FLUSH PRIVILEGES;
```

**正解：** B ✅

**解説：**
MariaDB は **ユーザー名と接続元ホストの組**で認証する。`'%'` は **TCP からの接続元**にマッチするが、**`localhost` にデフォルトで繋ぐクライアントは UNIX ドメインソケット**を使い、認証上は `'wpuser'@'localhost'` を探す。該当ユーザが無ければ拒否される。

補足の `unix_socket` 認証プラグインについて: これは MariaDB 固有の認証方式で、**OS のプロセスユーザー名**と DB ユーザー名が一致していれば認証を通す仕組み。ただし `-u wpuser` を省略した場合のデフォルトユーザーはコンテナ内の OS ユーザー（通常 `root`）であり、`wpuser` にはならない点に注意。

`wpuser@'localhost'` を追加する提案は技術的に正しいが、Inception の文脈では **root で `mariadb-admin ping`（DB 生存確認）、wpuser は WordPress からの TCP 接続専用**と役割を分けるほうがシンプル。`@'localhost'` を追加するとセキュリティの攻撃面が増える（コンテナ内から wpuser でローカル接続可能になる）ため、必要性とのトレードオフになる。

**一次資料：**
- [MariaDB KB — CREATE USER](https://mariadb.com/kb/en/create-user/)
- [MariaDB KB — How MariaDB authenticates connections](https://mariadb.com/kb/en/how-mariadb-authenticates-clients/)（接続方法と host の関係）
- [MariaDB KB — Authentication Plugin - Unix Socket](https://mariadb.com/kb/en/authentication-plugin-unix-socket/)

---

## Q11. レビューで「wpuser で ping が通らないのは？」と聞かれたとき（記述）

**質問:**  
0011 の Spike を踏まえ、**Inception では WordPress からの DB 接続に問題がない**ことを一言でどう説明するか（2〜3 文）。

**自分の回答：**
wordPressはスタブであり未実装なので現時点では何とも言えない。

**正解：** 不正解 ❌

WordPress は **`DB_HOST=mariadb` のようなホスト名で TCP 接続**する。`wpuser@'%'` は **TCP の接続元**にマッチする。問題になったのは **同一コンテナ内で `localhost`（ソケット）として `wpuser` で繋いだ**ケースであり、**WordPress が使うアプリケーション経路とは別**である。

**解説：**
この設問は「今 WordPress が動いているか」ではなく、**設計レベルで「将来 WordPress が繋ぐときに問題がないか」を説明できるか**を問うている。WordPress の `wp-config.php` は `DB_HOST=mariadb` を指定する予定であり、これは Docker のサービス名による **TCP 接続**。`wpuser@'%'` は TCP 接続元にマッチするため、**設計上問題はない**と断言できる。

レビューでは「未実装だからわからない」ではなく、**「テスト方法（コンテナ内 `localhost` ソケット）と本番経路（コンテナ間 TCP）の違い」を言語化**できると高評価になる。0011 の Spike でまさにこの整理をしているので、そこから引っ張れるとよい。

**一次資料：**
- `session_logs/0011_session_log_inception.md`（Spike 記録: 「Inception での影響」節）

---

## Q12. `mariadb-admin ping` を root で行う意味（選択）

**質問:**  
0011 の手順では **`docker exec mariadb mariadb-admin ping`**（ユーザ指定なし）で生存確認した。これが妥当な理由として最も近いものはどれか。

- A. root の方が ping が速いから  
- B. デフォルトはソケット接続で管理者（root）が許可されており、DB 生存確認に十分だから  
- C. wpuser はセキュリティ上削除済みだから  
- D. TLS クライアント証明書が必要だから  

**自分の回答：**
B.

**正解：** B ✅

**解説：**
`mariadb-admin ping` は **サーバプロセスが応答するか**を見るコマンドで、**UNIX ソケット経由の root（またはソケット認証が通るユーザ）**で足りる。アプリユーザ `wpuser` の **TCP 経路での接続テスト**は別コマンド（`mariadb -h mariadb -u wpuser -p` 等、別コンテナから実行）で行う、と役割を分ける。

**一次資料：**
- [MariaDB Admin — mariadb-admin](https://mariadb.com/kb/en/mariadb-admin/)

---

## Q13. 3 コンテナを同一ネットワークに載せる目的（記述）

**質問:**  
0011 で **MariaDB・wordpress スタブ・nginx** を **`inception-test-net` に同居**させた。NGINX が MariaDB に直接 SQL を投げるわけではないが、**同一ユーザ定義ネットワークに載せる意義**を、将来の compose 統合にもつなげて簡潔に述べよ。

**自分の回答：**
同一ネットーワークに乗せると、compoeで命名したアプリ名で名前解決が可能になるから。

**正解：** 部分正解 ⚠️

**コンテナ間の名前解決と到達性**を、ホストのポート公開に依存せずに検証するため。NGINX→WordPress（FastCGI, 9000）、WordPress→MariaDB（3306）など **サービス名／コンテナ名で相互参照**する構成に近い形で、**ネットワーク分離と DNS** の振る舞いを先に確認できる。compose では同様に **同一ネットワーク上のサービス名**が使われる。

**解説：**
名前解決が可能になるという点は合っている。不足しているのは2点:

1. **「NGINX が MariaDB に直接触らないのになぜ同一 net？」** への答え — compose では通常 **1つのネットワーク**に全サービスが載る。手動テストでその **トポロジ（全員が同一ネットワーク上にいる状態）** を再現しておくことで、compose 化したときに「手動で動いていたのに compose で動かない」を避けられる。
2. **ホストのポート公開（`-p`）に依存しない**コンテナ間通信の検証 — ユーザ定義ネットワーク上ではコンテナ同士が直接通信でき、ホスト側にポートを公開する必要がない。これは本番の compose 構成と同じ。

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

- 採点完了（2026-04-04）。選択式 7/7、記述式は Q11 を重点復習。
- `phase_plan.md` の「フェーズ2 事後クイズ」完了チェックは、**ドライバー確認のうえ**で `[x]` にすること。
