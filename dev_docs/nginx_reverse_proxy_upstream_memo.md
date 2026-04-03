# リバースプロキシと「上流」（upstream）— 1枚メモ

> 目的: タスク 2-1 で「クライアント → NGINX → **上流**」の **上流** が何を指すかを固定する。  
> 一次資料: [nginx `ngx_http_upstream_module`](https://nginx.org/en/docs/http/ngx_http_upstream_module.html)（`upstream` ディレクティブ）、[Beginner’s Guide](https://nginx.org/en/docs/beginners_guide.html)

---

## 「上流」は川の上流ではない

日本語の「上流」は誤解しやすい。**NGINX の文脈では、クライアントから見てネットワークの奥側にある、プロキシがリクエストを転送する先**のことである。英語では **upstream**（上流サーバ／アップストリーム）と呼ぶ。

- **クライアント**（ブラウザ、`curl` 等）: TLS で話す相手はまず NGINX。
- **NGINX**（リバースプロキシ）: クライアント向けに HTTPS を終端し、**別のプロセス・別コンテナ**へ HTTP や FastCGI 等で中継する。
- **上流（upstream）**: その「転送先」。アプリケーションサーバ（PHP-FPM）、別の HTTP サーバ、API バックエンドなど。

Inception では、例として **NGINX コンテナ → WordPress（PHP-FPM が `:9000` で待ち受け）** がこの「上流」に相当する。

---

## 図（例）

### ASCII（全体像）

```
  [ クライアント ]
  (ブラウザ / curl)
        |
        |  HTTPS :443（TLS はここで終わる）
        v
  +-------------+
  |   NGINX     |  ← リバースプロキシ（表向きの入口）
  |  (コンテナ)  |
  +-------------+
        |
        |  プロキシ転送（例: FastCGI）
        v
  +-------------+
  |  上流        |  ← upstream = 「転送先のバックエンド」
  | PHP-FPM      |     （川の上流ではなく、サービス構成の奥側）
  | :9000        |
  +-------------+
```

### Mermaid（同じ内容）

```mermaid
flowchart LR
  C[クライアント]
  N[NGINX リバースプロキシ]
  U[上流 upstream\n例: PHP-FPM :9000]

  C -->|HTTPS 443 TLS| N
  N -->|FastCGI 等| U
```

---

## 用語の対応関係（自分向け一言）

| 言い方 | 意味 |
|--------|------|
| 上流 / upstream | NGINX がプロキシで転送する**先**のサーバやプロセス群 |
| 下流 | 厳密には NGINX 公式が「下流」と呼ぶ用語としては使わないことが多い。混乱するなら **クライアント側**／**バックエンド側** で分ける |
| `fastcgi_pass` | 「上流」の **アドレス・ソケット**（例 `wordpress:9000`）へ FastCGI で渡す指令 |

---

## 設定ファイル階層（タスク 2-1 メモの1段落）

`nginx.conf` は大枠から **`events`**（接続処理の全体設定）→ **`http`**（HTTP に関するブロック）→ **`server`**（仮想ホスト単位、TLS の `listen 443 ssl` 等）→ **`location`**（パスごとの振る舞い、`fastcgi_pass` や静的ファイルのルート）という**入れ子**になる。`server` の中で TLS とサーバ名を決め、`location` で「この URL は静的」「この URL は PHP なので上流の PHP-FPM へ渡す」と分岐する、というイメージで読むと、`nginx.conf` 作成タスク（2-4）に繋がりやすい。

---

## 関連リンク（再掲）

- [ngx_http_fastcgi_module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html) — `fastcgi_pass`
- [ngx_http_proxy_module](https://nginx.org/en/docs/http/ngx_http_proxy_module.html) — HTTP で別サーバへ転送する場合（`proxy_pass`）
