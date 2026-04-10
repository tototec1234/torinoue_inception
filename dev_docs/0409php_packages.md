# PHP パッケージ選定記録

## 確定版

```sh
apk add --no-cache \
    # 1. 基盤
    php83 php83-fpm php83-phar \
    # 2. 通信・DB
    php83-curl php83-mysqli \
    # 3. データ形式
    php83-xml php83-dom \
    # 4. 文字処理
    php83-mbstring
```

### パッケージ一覧と選定理由

| パッケージ | 理由 |
|---|---|
| php83 | PHP 8.3 本体 |
| php83-fpm | Nginx と PHP を繋ぐプロセスマネージャー |
| php83-phar | WP-CLI の実行に必要 |
| php83-curl | WP-CLI が WordPress をダウンロードする際に使用 |
| php83-mysqli | MariaDB への接続 |
| php83-xml | WordPress の RSS・サイトマップ処理 |
| php83-dom | WordPress の HTML/XML 操作 |
| php83-mbstring | 日本語などのマルチバイト文字処理 |

---

## 選定プロセス

### 方針

- Nginx が SSL 終端を担うため `openssl` は不要
- 画像アップロード・プラグイン機能は対象外のため `imagick`, `exif`, `zip`, `fileinfo` は除外
- 実際にテストして組み込み済みと確認できたパッケージは除外

---

## テスト 1: json が組み込み済みか確認

### コマンド

```sh
docker run --rm alpine:3.21 sh -c "apk add --no-cache php83 && php83 -m | grep json"
```

### 結果

```
json
```

→ `php83-json` は**標準組み込み済み**。インストール不要。

---

## テスト 2: 全組み込みモジュールの確認

### コマンド

```sh
docker run --rm alpine:3.21 sh -c "apk add --no-cache php83 && php83 -m"
```

### 結果

```
[PHP Modules]
Core
date
filter
hash
json
libxml
pcre
random
readline
Reflection
SPL
standard
zlib

[Zend Modules]
```

### 判定

| モジュール | 状態 |
|---|---|
| json | 組み込み済み → 除外 |
| libxml | 組み込み済み |
| zlib | 組み込み済み |
| curl, mysqli, xml, dom, mbstring, phar, fpm | 組み込まれていない → **別途インストール必要** |
