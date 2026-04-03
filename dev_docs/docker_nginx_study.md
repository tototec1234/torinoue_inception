# Docker と Nginx の挙動に関するまとめ

一次資料（Dockerfile / 設定コメントに埋め込むときの候補と対応関係）:

- [nginx.org — Beginner’s Guide](https://nginx.org/en/docs/beginners_guide.html)（`nginx.conf` のブロック構造の入口）
- [ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)（TLS 終端: `ssl_certificate` / `ssl_protocols` 等）
- [ngx_http_fastcgi_module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)（`fastcgi_pass` / `fastcgi_param` 等）
- [ngx_core_module — `daemon`](https://nginx.org/en/docs/ngx_core_module.html#daemon)（`daemon off;` と設定ファイルの関係の補足）

## 1. CMD と ENTRYPOINT の違い
`docker run` を実行する際、Dockerfile に書かれた指示がどのように扱われるかの違いです。

### CMD (デフォルトの引数)
* **役割**: コンテナ起動時のデフォルトコマンドを指定します。
* **挙動**: `docker run` の後ろにコマンドを指定すると、`CMD` の内容は**完全に上書き**されます。
* **例**: `docker run myimage ls` を実行すると、Dockerfile の `CMD` は無視され `ls` が実行されます。

### ENTRYPOINT (実行の固定)
* **役割**: コンテナを「特定のツール」として動かすために実行ファイルを固定します。
* **挙動**: `docker run` の後ろに渡した引数は、`ENTRYPOINT` の**後ろに追加**されます。
* **例**: `ENTRYPOINT ["nginx"]` のとき `docker run myimage -v` と打つと、`nginx -v` が実行されます。

---

## 2. Nginx の -g オプションと "daemon off;"
### -g オプションとは
* **Global configuration** の略です。
* `nginx.conf` 内のグローバルコンテキストに記述する設定を、コマンドラインから直接指定・上書きするために使います。
* ロング形式（`--global` など）は存在せず、`-g` のみとなります。

### なぜ "daemon off;" が必要なのか
* **Docker の仕様**: コンテナは PID 1（メインプロセス）が終了すると停止します。
* **Nginx の標準動作**: 通常はバックグラウンド（デーモン）で動こうとするため、起動直後に親プロセスが終了してしまいます。（[`daemon` ディレクティブ](https://nginx.org/en/docs/ngx_core_module.html#daemon)）
* **解決策**: `daemon off;` を指定することで、Nginx をフォアグラウンドで動かし続け、コンテナが終了するのを防ぎます。詳細は `inception_nginx_daemon_memo.md` を参照。

---

## 3. 設定ファイル (nginx.conf) との使い分け
`daemon off;` は `nginx.conf` に直接記述することも可能ですが、以下の理由で `-g` で渡すのが一般的です。

1. **ポータビリティ**: 設定ファイルを Docker 以外（普通の VM など）でも使い回せるようにするため。
2. **役割の分離**: 「フォアグラウンド実行」はインフラ（Docker）側の要請であるため、設定ファイルではなく Dockerfile 側で制御する。

## 4. 構成上の注意点
提供された `torinoue_nginx.conf` のような構成において、`${SSL_DIR}` などの環境変数を使用する場合、Nginx 自体は変数展開をサポートしていないため、起動時に `envsubst` などでファイルを書き換えるか、フルパスで記述する必要があります。
