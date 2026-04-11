# Inception 課題 コンテキストサマリー

> 作成日: 2026-04-11
> 目的: 次のチャットへの引き継ぎ

---

## あなたのプロフィール

- **所属**: 42Tokyo 学生
- **経験**: C/C++ 経験あり、フロントエンド・インフラは初心者
- **現在取り組み中**: Inception 課題（Docker + WordPress + MariaDB + Nginx）

---

## 参考にしているリソース

### 1. kamitsui のドキュメント
- **URL**: https://kamitsui.github.io/Inception/
- **特徴**: 
  - 詳細なドキュメント付きの参考実装
  - `driver_opts: type: none, o: bind` を使った Volume 戦略を採用
  - `wp core download` は entrypoint.sh（setup.sh）内で実行（方針 B）

### 2. 友人の参考実装
- **特徴**:
  - Alpine Linux ベース
  - `wp core download` を Dockerfile 内で実行（方針 A）
  - entrypoint.sh に `wp core download` のガードがない（潜在的バグ）

---

## 今回のチャットで議論・学習した内容

### 1. `chown -R nobody:nobody` の意味
- `nobody:nobody` = ユーザー:グループ
- php-fpm が `nobody` として動作するため、ファイル所有者を合わせる必要がある
- セキュリティ上、root ではなく最小権限の nobody を使う

### 2. Linux パーミッションと所有者
- 所有者 = ファイルの持ち主（権限を管理する権利を持つ）
- パーミッション（rwx）は所有者/グループ/その他の3分類
- ACL（setfacl）を使えば特定ユーザーに個別に権限付与可能

### 3. Q7: `wp core download` のタイミング問題 ★重要★

#### 結論
**Inception 課題では方針 B（entrypoint.sh 内）が合理的**

#### 理由
- Inception では `driver_opts: type: none, o: bind` を使用
- この場合、ビルド時にイメージに焼き込んだファイルは起動時に bind mount で「隠れて」見えなくなる
- 結局 entrypoint.sh で再ダウンロードが必要 → ビルド時のダウンロードは**完全に無駄**
- ビルドキャッシュのメリットは「イメージ再ビルド時」のみ有効、コンテナ起動時には関係ない

#### 正しい実装（方針 B）
```bash
# entrypoint.sh
if [ ! -f /var/www/html/wp-settings.php ]; then
    wp core download
fi
```

#### 修正パッチ作成済み
- ファイル: `Q7_patch.md`
- 元のクイズファイルの正解を「方針 A が基本」から「方針 B が合理的」に修正

---

## 友人の Dockerfile（参考）

```dockerfile
FROM alpine:3.22
RUN apk update && apk add curl mariadb-client \
    php php-phar php-curl php-fpm php-mysqli php-json \
    php-dom php-exif php-fileinfo php-igbinary php-imagick \
    php-intl php-mbstring php-openssl php-xml php-zip
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp
RUN mkdir -p /var/www/html && chown -R nobody:nobody /var/www/html
WORKDIR /var/www/html
COPY conf/www.conf /etc/php83/php-fpm.d/
COPY tools/entrypoint.sh /
RUN chmod +x /entrypoint.sh
RUN php -d memory_limit=256M /usr/local/bin/wp core download  # ← 方針A（問題あり）
ENTRYPOINT ["/entrypoint.sh"]
```

---

## 友人の entrypoint.sh（参考）

```bash
#!/bin/ash

until mariadb-admin ping -h mariadb -u ${MARIADB_USER} -p${MARIADB_PASSWORD} --silent 2>/dev/null; do
    echo "waiting for mariaDB..."
    sleep 3
done
echo "mariaDB is ready"

if [ ! -f wp-config.php ]; then
    wp config create --dbhost=mariadb --dbname=$MARIADB_DATABASE --dbuser=$MARIADB_USER --dbpass=$MARIADB_PASSWORD
fi

if ! wp core is-installed 2>/dev/null; then
    wp core install \
       --url=takitaga.42.fr \
       --title="Inception" \
       --admin_user=$WP_ADMIN_USER \
       --admin_password=$WP_ADMIN_PASSWORD \
       --admin_email=$WP_ADMIN_EMAIL

    wp user create \
       $WP_USER \
       $WP_USER_EMAIL \
       --role=editor \
       --user_pass=$WP_USER_PASSWORD
fi

exec php-fpm83 -F
```

**問題点**: `wp core download` のガードがない → bind mount 構成だと初回起動で失敗する可能性

---

## 次のチャットで続けられるトピック

1. 友人の実装の修正（entrypoint.sh に `wp core download` ガード追加）
2. docker-compose.yml の volume 設定確認
3. Nginx / MariaDB コンテナの実装
4. その他 Inception 課題の質問

---

## 学習スタイルの希望（userPreferences より）

- 回答する前に質問して、レベルや状況を把握してから答える
- 忖度せず、正確な情報を率直に伝える
- わからないことは「わからない」と言う
