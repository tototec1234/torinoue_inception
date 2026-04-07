# curl --verbose で学ぶ TLS ハンドシェイクと HTTPS デバッグ

## 概要

このレポートは、`curl --verbose` の出力を読み解きながら TLS/SSL の仕組みを学んだ内容をまとめたものです。42Tokyo の Inception プロジェクトにおける nginx の HTTPS 設定デバッグを通じて得た知見を記録します。

---

## 1. 実験の背景

### 実行したコマンド

```bash
# 実験1: 通常のHTTPS接続
curl --verbose https://127.0.0.1/index.html

# 実験2: 証明書検証をスキップ
curl --insecure --verbose https://127.0.0.1/index.html
```

### 結果の比較

| 実験 | TLSハンドシェイク | HTTPレスポンス |
|------|------------------|----------------|
| 実験1 | 失敗（証明書エラー） | なし |
| 実験2 | 成功 | 502 Bad Gateway |

---

## 2. curl --verbose の出力の読み方

### 2.1 出力の記号の意味

| 記号 | 意味 |
|------|------|
| `*` | curlの内部情報（接続状態、TLS情報など） |
| `>` | クライアント → サーバー（送信データ） |
| `<` | サーバー → クライアント（受信データ） |

### 2.2 TLS (OUT) と TLS (IN) の意味

視点は常に **curl（クライアント）側** です。

| 表記 | 意味 | 方向 |
|------|------|------|
| `OUT` | クライアント → サーバー | 送信 |
| `IN` | サーバー → クライアント | 受信 |

### 2.3 「TLS header」と「TLS handshake」の違い

出力には2種類のメッセージがあります。

| 種類 | 意味 |
|------|------|
| `TLS handshake` | 実際のハンドシェイクメッセージ（本体） |
| `TLS header` | パケットのヘッダー情報（包み紙） |

**重要**: `TLS header` の行に表示されるバージョン番号（TLSv1.0, TLSv1.2）は、後方互換性のために使用される番号であり、実際の通信バージョンではありません。実際に使用されるバージョンは `SSL connection using TLSv1.3` の行で確認できます。

---

## 3. TLS 1.3 ハンドシェイクの流れ

### 3.1 実際の出力から抽出した TLS 1.3 メッセージ

```
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
```

### 3.2 各メッセージの役割

| メッセージ | 方向 | 説明 |
|-----------|------|------|
| Client Hello | OUT | クライアントが接続要求、対応する暗号スイートを提示 |
| Server Hello | IN | サーバーが暗号スイートを選択 |
| Encrypted Extensions | IN | TLS 1.3で追加。暗号化された追加設定情報 |
| Certificate | IN | サーバーの証明書を送信 |
| CERT verify | IN | 証明書の検証情報 |
| Change cipher spec | OUT | 互換性のための信号（TLS 1.3では技術的には不要） |
| Finished | OUT/IN | ハンドシェイク完了の合図 |

### 3.3 ハンドシェイクのシーケンス図

```
    curl (クライアント)                    nginx (サーバー)
          |                                      |
          |  -------- Client Hello ---------->   |  (OUT)
          |  <------- Server Hello -----------   |  (IN)
          |  <------- Encrypted Extensions ---   |  (IN)
          |  <------- Certificate ------------   |  (IN)
          |  <------- CERT verify ------------   |  (IN)
          |  -------- Change cipher spec ---->   |  (OUT)
          |  -------- Finished -------------->   |  (OUT)
          |                                      |
          |========== 暗号化通信確立 ============|
```

---

## 4. TLS バージョンの互換性設計

### 4.1 なぜヘッダーのバージョンが異なるのか

出力を見ると、ヘッダーには `TLSv1.0` や `TLSv1.2` と表示されていますが、実際には `TLSv1.3` で通信しています。

```
* TLSv1.0 (OUT), TLS header, Certificate Status (22):
* TLSv1.2 (IN), TLS header, Certificate Status (22):
...
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
```

これは **後方互換性** のための設計です。

### 4.2 Protocol Ossification（プロトコル硬直化）問題

TLS 1.3を設計した際、世界中に「バージョン番号が1.3だと拒否する古い機器（ミドルボックス）」が大量に存在することが判明しました。

そのため、TLS 1.3では以下の設計を採用しています。

- ヘッダーには TLS 1.2 以下のバージョンを記載
- 実際の中身で TLS 1.3 をネゴシエーション
- Server Hello 内の拡張ヘッダーで「実際は TLS 1.3」であることを伝達

---

## 5. 自己署名証明書のエラー

### 5.1 エラーの内容

```
* TLSv1.3 (OUT), TLS alert, unknown CA (560):
* SSL certificate problem: self-signed certificate
* Closing connection 0
```

### 5.2 解説

- `unknown CA`: 証明書を発行した認証局（CA）を知らない
- 自己署名証明書は、第三者の CA ではなく自分自身で署名しているため、curl のデフォルトでは信頼されない
- `--insecure` オプションで検証をスキップ可能

### 5.3 --insecure 使用時の出力

```
* SSL certificate verify result: self-signed certificate (18), continuing anyway.
```

警告は出るが、`continuing anyway` で接続を続行します。

---

## 6. 502 Bad Gateway エラー

### 6.1 エラーの意味

```
< HTTP/1.1 502 Bad Gateway
< Server: nginx/1.26.3
```

502 Bad Gateway は、nginx がゲートウェイまたはプロキシとして動作している際に、上流（upstream）サーバーから有効なレスポンスを受け取れなかったことを示します。

### 6.2 このエラーから分かること

1. **nginx は正常に動作している**（レスポンスを返せている）
2. **TLS/SSL 接続は成功している**
3. **nginx の背後のサービス（upstream）に問題がある**

### 6.3 考えられる原因

- PHP-FPM や WordPress コンテナが起動していない
- `proxy_pass` や `fastcgi_pass` の設定が間違っている
- ソケットやポートの接続先が存在しない

---

## 7. 学んだことのまとめ

1. **curl --verbose は TLS デバッグに非常に有用**
   - ハンドシェイクの各ステップを確認できる
   - 証明書情報を確認できる
   - エラーの発生箇所を特定できる

2. **TLS header と TLS handshake は別物**
   - header のバージョン番号は互換性のためのもの
   - 実際のバージョンは `SSL connection using` で確認

3. **OUT/IN はクライアント視点**
   - OUT = クライアントからサーバーへ送信
   - IN = サーバーからクライアントへ受信

4. **エラーは段階的に切り分ける**
   - TLS エラー → 証明書や暗号スイートの問題
   - HTTP エラー → アプリケーション層の問題
   - 502 → upstream サービスの問題

---

## 参考資料

### 日本語資料

- [SSL/TLSについてまとめてみた - Zenn](https://zenn.dev/m_keiichi/articles/6b69599daadc8c)

### 一次資料（RFC・公式ドキュメント）

- [RFC 8446 - The Transport Layer Security (TLS) Protocol Version 1.3](https://datatracker.ietf.org/doc/html/rfc8446) - TLS 1.3 の公式仕様書（IETF）
- [curl Manual - verbose option](https://curl.se/docs/manpage.html) - curl 公式マニュアル

### 解説記事

- [A Detailed Look at RFC 8446 (a.k.a. TLS 1.3) - Cloudflare Blog](https://blog.cloudflare.com/rfc-8446-aka-tls-1-3/) - TLS 1.3 の詳細な解説
- [Deploying TLS 1.3 - Internet Society](https://www.internetsociety.org/blog/2018/08/deploying-tls-1-3/) - TLS 1.3 の導入ガイド
- [NGINX 502 Bad Gateway: PHP-FPM | Datadog](https://www.datadoghq.com/blog/nginx-502-bad-gateway-errors-php-fpm/) - 502 エラーのトラブルシューティング

---

## 付録: 暗号スイートの読み方

例: `TLS_AES_256_GCM_SHA384`

| 要素 | 意味 |
|------|------|
| TLS | プロトコル |
| AES_256 | 暗号化アルゴリズム（256ビット AES） |
| GCM | 暗号利用モード（Galois/Counter Mode） |
| SHA384 | ハッシュ関数（SHA-384） |

※ TLS 1.3 では鍵交換アルゴリズムは暗号スイート名に含まれず、別途ネゴシエーションされます。

---
## 追加実験：TLS 1.2 を強制してみる
TLS 1.2 で接続できるか確認したい場合：
```bash
curl --insecure --verbose --tlsv1.2 --tls-max 1.2 https://127.0.0.1/
```

これで `SSL connection using TLSv1.2 / ...` と表示されれば、TLS 1.2 も正しく動作している。

---

*作成日: 2026年4月5日*
*42Tokyo Inception プロジェクト学習記録*
