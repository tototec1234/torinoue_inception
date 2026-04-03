# Dockerコンテナの起動プロセスとvolumeマウントのタイミング

> 作成日: 2026-03-26  
> 対象: Inception課題 - MariaDBコンテナ設計  
> 関連ファイル: `srcs/requirements/mariadb/Dockerfile`, `srcs/requirements/mariadb/tools/entrypoint.sh`

---

## 概要

このドキュメントは、Dockerコンテナの起動プロセスにおける**volumeマウントのタイミング**と、それが**データディレクトリの可視性**に与える影響を説明します。

特に、「なぜDockerfileでのデータベース初期化が無意味になるのか」という設計判断の根拠を明確にします。

---

## フェーズ1: `docker build` 時（イメージレイヤー構築）

### 実行される処理

```dockerfile
# 1. ベースイメージ
FROM alpine:3.21
# → ベースレイヤー

# 2. パッケージインストール
RUN apk add --no-cache mariadb mariadb-client
# → 新しいレイヤー（パッケージ追加）

# 3. ディレクトリ作成と権限設定
RUN mkdir -p /run/mysqld /var/lib/mysql && \
    chown -R mysql:mysql /run/mysqld /var/lib/mysql
# → 新しいレイヤー（ディレクトリ作成 + 権限設定）
# ★ この時点で /var/lib/mysql は「空のディレクトリ」としてイメージに焼き込まれる

# 4. 設定ファイルコピー
COPY conf/zaphod-mariadb.cnf /etc/my.cnf.d/
# → 新しいレイヤー（設定ファイル追加）

# 5. エントリポイントスクリプトコピー
COPY tools/entrypoint.sh /
RUN chmod +x /entrypoint.sh
# → 新しいレイヤー（スクリプト追加）
```

### レイヤー構造

```
[Layer 5] entrypoint.sh + 実行権限
[Layer 4] zaphod-mariadb.cnf
[Layer 3] /var/lib/mysql (空ディレクトリ) + /run/mysqld
[Layer 2] mariadb パッケージ
[Layer 1] alpine:3.21 ベース
```

### 重要ポイント

- **この時点では `/var/lib/mysql` は空のディレクトリ**
- **volumeマウントはまだ発生していない**
- イメージレイヤーは読み取り専用で不変

---

## フェーズ2: `docker run` / `docker-compose up` 時（コンテナ起動）

### 2-1. コンテナ作成（volumeマウント発生）

```yaml
# docker-compose.yml
services:
  mariadb:
    volumes:
      - mariadb_data:/var/lib/mysql  # ★★★ ここでマウント発生 ★★★
```

#### マウントのメカニズム（Union File System）

```
[イメージレイヤー（読み取り専用）]
  Layer 5: entrypoint.sh
  Layer 4: zaphod-mariadb.cnf
  Layer 3: /var/lib/mysql (空)  ← ★ この層は隠される
  Layer 2: mariadb
  Layer 1: alpine:3.21

         ↓ volumeマウントで上書き

[コンテナ実行時の /var/lib/mysql]
  → Named Volume「mariadb_data」を指す
  → イメージの /var/lib/mysql は完全に隠される（アクセス不可）
```

#### 重要ポイント

- **volumeマウントは「コンテナ作成時」に発生**（ENTRYPOINTより前）
- イメージレイヤーの `/var/lib/mysql` は「隠される」（上書きではない）
- Named Volume が空の場合、コンテナから見える `/var/lib/mysql` も空

---

### 2-2. ENTRYPOINT 実行（`/entrypoint.sh` 起動）

```bash
#!/bin/sh

# ★ この時点で /var/lib/mysql は Named Volume を指している
# ★ 初回起動時は Volume が空なので、/var/lib/mysql/mysql は存在しない

if [ ! -d "/var/lib/mysql/mysql" ]; then
    # 初回起動時のみ実行される
    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql \  # ← Named Volume に書き込まれる
        --basedir=/usr
    
    # 一時起動（TCP無効、ソケット経由のみ）
    mariadbd --user=mysql --skip-networking &
    
    # MariaDB起動待機
    i=0
    while ! mariadb-admin ping --silent; do
        i=$((i + 1))
        if [ $i -gt 42 ]; then
            echo "MariaDB did not start in time" >&2
            exit 1
        fi
        sleep 1
    done
    
    # SQL実行（CREATE DATABASE / USER / GRANT）
    mariadb --user root <<EOF
    CREATE DATABASE IF NOT EXISTS $MARIADB_DATABASE;
    CREATE USER IF NOT EXISTS '$MARIADB_USER'@'%' IDENTIFIED BY '$MARIADB_PASSWORD';
    GRANT ALL PRIVILEGES ON $MARIADB_DATABASE.* TO '$MARIADB_USER'@'%';
    FLUSH PRIVILEGES;
EOF
    
    # 一時起動をシャットダウン
    mariadb-admin --user=root shutdown
fi

# 本番起動（PID 1として）
exec mariadbd --user=mysql
```

#### 実行フロー

```
1. コンテナ作成
   ↓
2. ★★★ Named Volume マウント ★★★
   /var/lib/mysql → mariadb_data にマウント
   （イメージの /var/lib/mysql は隠される）
   ↓
3. ENTRYPOINT 実行（/entrypoint.sh）
   - Volume が空 → 初期化実行
   - Volume に既存データ → スキップ
   ↓
4. mariadbd 起動（PID 1）
```

---

## なぜDockerfileでの初期化が無意味になるのか

### アンチパターン例

```dockerfile
# ❌ 間違った設計
RUN mariadb-install-db --user=mysql --datadir=/var/lib/mysql
```

### 何が起こるか

```
[ビルド時]
  mariadb-install-db 実行
    ↓
  /var/lib/mysql にシステムテーブル作成
    ↓
  この内容は「Layer 3」に焼き込まれる

[起動時]
  コンテナ作成
    ↓
  Named Volume が /var/lib/mysql にマウント
    ↓
  ★★★ Layer 3 の /var/lib/mysql は隠される ★★★
    ↓
  空の Volume が見える
    ↓
  結果: ビルド時の初期化が完全に無駄
```

### 正しい設計

- **ビルド時**: ディレクトリ作成と権限設定のみ
- **起動時**: entrypoint.sh で初期化（Volume が空の場合のみ）

この設計により、Volume の永続性を保ちながら初回起動時の初期化を実現できます。

---

## 確認実験

### 実験1: イメージレイヤーの内容を確認

```bash
# ビルド済みイメージの /var/lib/mysql を確認（volumeマウント前）
docker run --rm --entrypoint sh <イメージ名> -c "ls -la /var/lib/mysql"
```

**予想結果**: 空のディレクトリ（または `.` と `..` のみ）

### 実験2: コンテナ起動後のマウント状態を確認

```bash
# コンテナ起動（volumeマウント後）
docker-compose up -d mariadb

# コンテナ内で確認
docker-compose exec mariadb sh -c "ls -la /var/lib/mysql"
```

**予想結果**: 初回起動後は `mysql/` ディレクトリが存在（Named Volume に書き込まれた）

### 実験3: マウントポイントの確認

```bash
# volumeのマウント情報を確認
docker inspect <コンテナID> | grep -A 10 "Mounts"
```

**予想結果**:
```json
"Mounts": [
    {
        "Type": "volume",
        "Name": "srcs_mariadb_data",
        "Source": "/var/lib/docker/volumes/srcs_mariadb_data/_data",
        "Destination": "/var/lib/mysql",
        "Driver": "local",
        "Mode": "rw"
    }
]
```

---

## まとめ: 時系列とレイヤー構造

```
[ビルド時]
  Dockerfile実行
    ↓
  イメージレイヤー構築
    - /var/lib/mysql は空ディレクトリとして記録
    - entrypoint.sh はコピーされる
    ↓
  イメージ完成（不変）

[起動時]
  docker-compose up
    ↓
  (1) コンテナ作成
    ↓
  (2) ★★★ Named Volume マウント ★★★
      /var/lib/mysql → mariadb_data にマウント
      （イメージの /var/lib/mysql は隠される）
    ↓
  (3) ENTRYPOINT 実行（/entrypoint.sh）
      - Volume が空 → 初期化実行
      - Volume に既存データ → スキップ
    ↓
  (4) mariadbd 起動（PID 1）
```

---

## 補足: `ash` と `bash` の違い

entrypoint.sh で `#!/bin/sh` を使っている理由：

- Alpine Linux には `bash` が含まれていない（軽量化のため）
- `sh` は `ash`（Almquist Shell）にシンボリックリンクされている
- `ash` は POSIX 準拠で、基本的なシェル機能は使える
- 配列や高度な文字列操作など、bash 固有の機能は使えない

**確認コマンド**:
```bash
docker run --rm alpine:3.21 sh -c "ls -l /bin/sh"
# 出力: lrwxrwxrwx ... /bin/sh -> /bin/busybox
```

---

## 参考資料

- Docker公式ドキュメント: [Use volumes](https://docs.docker.com/storage/volumes/)
- MariaDB公式ドキュメント: [mariadb-install-db](https://mariadb.com/kb/en/mariadb-install-db/)
- Alpine Linux Wiki: [MariaDB](https://wiki.alpinelinux.org/wiki/MariaDB)

---

## このドキュメントの活用方法

- **README.md 作成時**: 「設計判断の根拠」セクションで参照
- **DEV_DOC.md 作成時**: 「技術的な詳細」セクションで参照
- **レビュー対応時**: 「なぜ起動時初期化が必要か」の説明根拠として使用
- **セッションログ**: 将来のセッションで設計判断を振り返る際の参照元
