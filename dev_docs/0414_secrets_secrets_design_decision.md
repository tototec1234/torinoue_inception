# Inception プロジェクト — Secrets 管理の設計決定書

## 概要

本ドキュメントは、42 Inception プロジェクトにおける Docker Secrets（機密情報ファイル）の管理方式について、検討経緯・比較・最終決定を記録したものである。

レビュアーへの説明資料を兼ねるため、subject の要件解釈と設計根拠を併記する。

---

## 前提条件

### Subject の要件（v5.2）

| 要件 | 記載箇所 | 要約 |
|------|----------|------|
| `.env` ファイルの使用 | Ch.V p.8 警告ボックス | **mandatory（必須）** |
| Docker Secrets の使用 | Ch.V p.8 警告ボックス | **strongly recommended（強く推奨）** |
| Git に credentials を含めない | Ch.V p.8 警告ボックス | "Any credentials, API keys, or passwords found in your Git repository (outside of properly configured secrets) will result in project failure." |
| `secrets/` ディレクトリの存在 | Ch.V p.10 構造例 | ルート直下に `secrets/` が表示されている |
| credentials を git で無視する | Ch.V p.10 下部警告 | "must be saved locally in various ways/files and ignored by git" |
| DEV_DOC.md に環境構築手順 | Ch.VII p.14 | "Set up the environment from scratch (prerequisites, configuration files, secrets)" |

### Subject のディレクトリ構造例に関する解釈

Subject p.10 のディレクトリ構造例では `./secrets/` がルート直下に表示されている。しかし同じページの警告ボックスで「credentials は git に含めるな」と明記されている。

**したがって、この構造例は「Git リポジトリ上の状態」ではなく「VM 上で最終的にあるべき状態」を示していると解釈する。** `secrets/` を Git に含めた場合、中身が空であっても「なぜ空なのか」「どう使うのか」がレビュアーに伝わりにくく、設計の意図と矛盾する。

### 本プロジェクト固有の構成

- **Vagrant** を使用して VM を自動構築する（校舎 Ubuntu/VirtualBox と M2 Mac の差を吸収）
- ルート直下の `Makefile` は `vagrant ssh` 経由で VM 内の `make` を実行する
- `docker-compose.yml` の secrets 定義は **VM 内の絶対パス**（`/home/<login>/secrets/`）を参照する
- `secrets/` ディレクトリおよび中身の `.txt` ファイルは **VM 内にのみ存在** する

---

## 検討した 4 つの案

### 案 1：空ファイルを Git に含め、レビュー時に手入力

secrets ディレクトリと空の `.txt` ファイルを Git に含め、レビュー開始後にレビュアーにパスワードを手入力してもらう方式。

**想定する運用：**

```
# Git 上の状態
secrets/
├── credentials.txt      # 空ファイル
├── db_password.txt       # 空ファイル
└── db_root_password.txt  # 空ファイル
```

レビュー開始後、レビュイーがメモを渡し、レビュアーが各ファイルにパスワードを記入する。

### 案 2：sample ディレクトリに平文でパスワードを Git に push

`/sample` などのディレクトリを作成し、`.gitignore` せずにパスワードファイルをそのまま Git に push する方式。

### 案 3：git-crypt で暗号化して Git に含める

`.gitattributes` で `secrets/*.txt` を暗号化対象に指定し、git-crypt を使って暗号化した状態で Git に含める方式。

### 案 4：VM 構築時に Makefile で自動生成（採用）

`secrets/` ディレクトリもファイルも Git には一切含めず、Vagrant up 時に `vm/Makefile`（init.sh）がランダムパスワードを生成して VM 内に配置する方式。

---

## 4 案の比較表

| 評価項目 | 案 1：空ファイル＋手入力 | 案 2：平文で push | 案 3：git-crypt | 案 4：VM で自動生成（採用） |
|----------|------------------------|------------------|----------------|--------------------------|
| **Git に credentials が入るか** | 入らない（空ファイルのみ） | **入る** | 暗号化状態で入る | 入らない |
| **subject 違反リスク** | 低い | **即不合格** | グレー | なし |
| **レビュアーの手間** | 大きい（手入力が必要） | なし | 鍵の受け渡しが必要 | なし（自動生成） |
| **レビュアー環境の前提** | なし | なし | git-crypt のインストール | なし |
| **レビュー中の再起動耐性** | パスワード再入力が必要 | 問題なし | 問題なし | 問題なし（VM 内に保持） |
| **Git 上の構造と実態の整合性** | 低い（空ファイルが存在する理由の説明が必要） | 高いが危険 | 中程度 | 高い（Git に不要なものがない） |
| **DEV_DOC.md での説明のしやすさ** | やや複雑 | 簡単だが不合格 | 複雑（git-crypt の説明が必要） | 明快 |
| **総合評価** | △ 安全だが運用が煩雑 | × 不合格 | △ 技術的に面白いが依存が大きい | ◎ 安全・簡潔・自動 |

---

## 案 4 の詳細設計

### ディレクトリ構成（Git リポジトリ上）

```
.                           # Git リポジトリルート
├── Makefile                # vagrant ssh 経由で srcs 内の make を呼ぶ
├── README.md               # 英語、subject 所定のセクションを含む
├── USER_DOC.md             # ユーザードキュメント
├── DEV_DOC.md              # 開発者ドキュメント
├── vm/
│   ├── Vagrantfile
│   ├── Makefile            # vagrant up 用、secrets 生成を含む
│   └── init.sh             # Vagrant provisioning スクリプト
└── srcs/
    ├── docker-compose.yml
    ├── .env                # 非機密情報（Git に含める）
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/
        │   └── tools/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/
        │   └── tools/
        └── wordpress/
            ├── Dockerfile
            ├── .dockerignore
            ├── conf/
            └── tools/
```

**注意：`secrets/` ディレクトリは Git 上に存在しない。**

### VM 内の最終的な状態

```
/home/<login>/
├── data/                   # Docker named volumes のデータ
│   ├── db/                 # MariaDB データ
│   └── wordpress/          # WordPress ファイル
├── secrets/                # init.sh により自動生成
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
└── project/                # git clone 先（またはVagrant synced folder）
    ├── Makefile
    ├── srcs/
    │   ├── docker-compose.yml
    │   ├── .env
    │   └── requirements/
    └── ...
```

### Secrets 自動生成の仕組み（init.sh の該当部分）

```bash
#!/bin/bash

SECRETS_DIR="/home/<login>/secrets"

# secrets ディレクトリが存在しない場合のみ生成
if [ ! -d "$SECRETS_DIR" ]; then
    mkdir -p "$SECRETS_DIR"

    # ランダムパスワードを生成
    openssl rand -base64 16 > "$SECRETS_DIR/db_password.txt"
    openssl rand -base64 16 > "$SECRETS_DIR/db_root_password.txt"

    # WordPress 管理者の credentials（ユーザー名は admin を含まない）
    echo "wp_boss" > "$SECRETS_DIR/credentials.txt"
    openssl rand -base64 16 >> "$SECRETS_DIR/credentials.txt"

    # パーミッション設定
    chmod 600 "$SECRETS_DIR"/*.txt

    echo "=== Secrets generated ==="
    echo "DB password:      $(cat $SECRETS_DIR/db_password.txt)"
    echo "DB root password:  $(cat $SECRETS_DIR/db_root_password.txt)"
    echo "WP credentials:    $(cat $SECRETS_DIR/credentials.txt)"
    echo "========================="
fi
```

**ポイント：**

- `vagrant up` は 1 レビュアーあたり 1 回のみ実行される想定
- `if [ ! -d ... ]` により、secrets がすでに存在する場合は再生成しない
- レビュー中に srcs 以下を変更して `make` で再起動しても、secrets は変わらない
- 生成されたパスワードは標準出力に表示されるので、レビュー時に確認可能

### docker-compose.yml での secrets 参照

```yaml
secrets:
  db_password:
    file: /home/<login>/secrets/db_password.txt
  db_root_password:
    file: /home/<login>/secrets/db_root_password.txt
  credentials:
    file: /home/<login>/secrets/credentials.txt

services:
  mariadb:
    # ...
    secrets:
      - db_password
      - db_root_password
  wordpress:
    # ...
    secrets:
      - db_password
      - credentials
```

コンテナ内では `/run/secrets/<secret_name>` としてマウントされる。

---

## 採用理由のまとめ

1. **subject の要件を完全に満たす。** Git リポジトリに credentials が一切含まれないため、"project failure" のリスクがゼロである。

2. **レビュアーの負担が最小。** `vagrant up`（または `make`）を実行するだけで secrets が自動生成される。手入力、鍵の受け渡し、追加ツールのインストールは不要である。

3. **レビュー中の再起動に強い。** secrets は VM 内に保持されるため、srcs 以下の変更と `make` による再起動を繰り返しても、パスワードが変わらない。レビュアーは同じ credentials で WordPress 管理画面に何度でもアクセスできる。

4. **Git 上の構造と実態が一致する。** Git に不要なもの（空ディレクトリ、暗号化ファイル）がないため、「これは何？」という無駄な疑問が生じない。secrets の所在と生成方法は DEV_DOC.md に記載し、レビュアーはそれを読んで理解できる。

5. **subject のディレクトリ構造例との整合性がある。** 構造例は「VM 上の最終状態」を示しており、VM 内で `ls` すれば `secrets/` ディレクトリが存在する。Git 上の状態ではない。

---

## vm/ ディレクトリの配置根拠

`vm/` ディレクトリをルート直下（`srcs/` の外）に配置する理由：

- Subject は「All the files required for the configuration of your project must be placed in a srcs folder」と規定しており、ルート直下の `Makefile` は docker-compose.yml を使ってビルドするものである。`vm/Makefile` は Vagrant 用であり、これと衝突させない。
- `srcs/` 内に置くと、レビュアーの「操作対象」に含まれ、「ここをこう変えたらどうなる？」という議論に発展し、課題の本筋（Docker Compose）から逸れるリスクがある。
- ルート直下であれば `*.md` ファイルと同様に「読んでもらうが、操作対象ではない」という位置づけになる。

---

## .env と secrets の役割分担

| 項目 | 管理方法 | Git に含めるか | 例 |
|------|----------|---------------|-----|
| ドメイン名 | `.env` | はい | `DOMAIN_NAME=login.42.fr` |
| MySQL ユーザー名 | `.env` | はい | `MYSQL_USER=wp_user` |
| MySQL データベース名 | `.env` | はい | `MYSQL_DATABASE=wordpress` |
| MySQL パスワード | Docker Secrets | いいえ | `secrets/db_password.txt` |
| MySQL root パスワード | Docker Secrets | いいえ | `secrets/db_root_password.txt` |
| WordPress 管理者 credentials | Docker Secrets | いいえ | `secrets/credentials.txt` |

---

## レビュー時の想定フロー

1. レビュアーがレビュイーの iMac に移動する
2. sgoinfre 内で `git clone` する（Vagrant box のキャッシュは事前に存在）
3. `make` を実行する → `vm/Makefile` が `vagrant up` を実行
4. init.sh が VM を provisioning し、secrets を自動生成（初回のみ）
5. `vagrant ssh` で VM に入り、`make` で docker compose up が実行される
6. ブラウザで `https://login.42.fr` にアクセスし、WordPress の動作を確認
7. 生成された credentials（`vagrant up` 時の出力）で WordPress 管理画面にログイン
8. srcs 以下のファイルを変更・再ビルドしても secrets は維持される
9. `make credentials`（任意実装）で現在のパスワードを再表示可能

---

*本ドキュメントは 42 Inception プロジェクトの設計検討過程で作成された。*
*Subject Version: 5.2*
