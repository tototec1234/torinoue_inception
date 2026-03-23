# Inception 事前理解クイズ - WordPress編

---

## Q1. WordPressがMariaDBに接続するとき、ホスト名として何を指定しますか？

**自分の回答：**
`mariadb`（サービス名）。docker-compose.ymlで定義されており、42の課題ではコンテナ名と一致することが求められている。またmariadb/DockerfileでEXPOSEで定義されている3306ポート。

**正解：**
ホスト名は `mariadb`（docker-compose.ymlのサービス名）。ポート番号は `3306`。

**解説：**
DockerはComposeで定義された同一ネットワーク内のサービスに対して、**サービス名でDNS解決**してくれます。つまり `mariadb` というホスト名でアクセスすると、自動的にmariadbコンテナのIPに解決されます。

`EXPOSE 3306` はホスト名とは無関係です。EXPOSEはそのコンテナが使うポートを**ドキュメントとして宣言**するものであり、実際の通信を制御するものではありません。

**図解：**
```
WordPressコンテナ
  └── wp-config.php に書く接続先
      DB_HOST = mariadb   ← サービス名（DockerのDNSが解決）
      DB_PORT = 3306      ← MariaDBが待ち受けるポート
```

**ペアレビューで聞かれそうな追加質問：**
- `EXPOSE` の意味は？ → コンテナが使うポートの宣言。実際の通信制御はしない
- なぜIPアドレスではなくサービス名で接続できるのですか？ → DockerのネットワークがサービスDNSを提供しているから
- 42の課題でコンテナ名とサービス名を一致させる理由は？ → wp-config.phpのDB_HOSTにサービス名を使うため、明確にするためのルール

---

## Q2. WordPressコンテナに必要なものは何ですか？

**自分の回答：**
1. Dockerfile：WordPressのダウンロード元、HTMLが保存されるべき場所、nginxに公開するポート、mariadbに公開するポート、起動時に呼び出すスクリプト
2. init.sh：サーバーを起動する。バックエンドとフロントエンドを用意する
3. フロントエンドのHTMLファイル
4. バックエンドのJSファイル

**正解：**
1. `Dockerfile` — ベースイメージ・PHP-FPMインストール・wp-cli配置・init.sh配置
2. `conf/init.sh` — WordPressダウンロード・wp-config.php生成・WP初期設定・PHP-FPM起動
3. `conf/www.conf`（任意） — PHP-FPMの設定ファイル

HTMLファイルやJSファイルは**自分で書かない**。

**解説：**
WordPressは**PHPで動くCMS（コンテンツ管理システム）**です。HTMLやJSはWordPress自身が生成します。自分で書く必要はありません。

コンテナに必要なのはWordPressを**動かすための環境と設定**です。

**3コンテナの役割と通信の流れ：**
```
ブラウザ
  ↓ HTTPS（ポート443）
NGINXコンテナ（/var/www/html/ の静的ファイルを返す、PHPはWPに転送）
  ↓ FastCGI（ポート9000）
WordPressコンテナ（PHP-FPMでPHPを実行、/var/www/html/ にWPのソース）
  ↓ TCP（ポート3306）
MariaDBコンテナ（データの読み書き）
```

**PHP-FPMとは：**
PHP FastCGI Process Managerの略。PHPスクリプトを実行するプロセスマネージャーです。NGINXはPHPを直接実行できないため、PHP-FPMにリクエストを転送します。

**WordPressコンテナに必要なファイル：**

| ファイル | 場所（コンテナ内） | 役割 |
|----------|-------------------|------|
| WordPressのソースコード | `/var/www/html/` | WP本体（init.shでダウンロード） |
| wp-config.php | `/var/www/html/wp-config.php` | DB接続情報・WP設定 |
| PHP-FPM | `/usr/sbin/php-fpm8.2` など | PHPを実行するプロセス |

**ペアレビューで聞かれそうな追加質問：**
- NGINXとWordPressはどうやって通信しますか？ → FastCGI（ポート9000）経由
- wp-config.phpには何を書きますか？ → DB_HOST, DB_NAME, DB_USER, DB_PASSWORDなどの接続情報
- WordPressのソースコードはどこからダウンロードしますか？ → `wp-cli`（WordPress公式CLIツール）を使う
