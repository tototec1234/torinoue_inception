# フェーズ4 事前クイズ - Docker Compose ・ secrets 編

> 作成日: 2026-04-12
> 対象フェーズ: 4（Docker Compose 統合 + secrets）
> 実施タイミング: フェーズ4 開始前（タスク 4-2 `docker-compose.yml` 実施前）
> 採点日: 2026-04-14（`phase_plan.md` クイズ運用ルール **ステップ4**: 正解・解説を各 Q に追記済み）
> 実施記録: セッション `#0024`、実作業 **8.0h**（開始 2026-04-13 14:08 〜 終了 2026-04-14 13:24）。詳細は `session_logs/0024_session_log_inception.md`。

本ファイルは **ステップ1** で問題・一次資料・「自分の回答」を用意し、**ステップ4（採点）** で下記 **正解・解説** を追記済みです。

**本課題の方針メモ（`phase_plan.md` より）:** 課題書に healthcheck の明示がないため、**提出物の `docker-compose.yml` には healthcheck を書かない**。`depends_on` と **entrypoint 側の DB 待機**で起動順・可用性を担保する。以下の healthcheck 関連の設問は**理解確認用**です。

---

## Q1. Named volume と bind mount の違い

Docker のデータ永続化において、**named volume（名前付きボリューム）**と **bind mount** の違いを、次の観点で説明してください。

- データの実体がどこに置かれるか（誰がパス・ライフサイクルを管理するか）
- ホストのディレクトリ構成への依存の強さ（移植性）
- 一般的な使い分けの例（DB データ、設定ファイルの開発時マウントなど）

**自分の回答：**

### データの実体の場所

| 種類 | 実体の場所 | 管理者 |
|------|-----------|--------|
| Named Volume | `/var/lib/docker/volumes/<name>/_data` | Docker |
| Bind Mount | ユーザー指定の任意のホストパス | ユーザー |

### 移植性

| 種類 | 移植性 | 理由 |
|------|--------|------|
| Named Volume | 高い | Dockerが管理、ホストのディレクトリ構造に依存しない |
| Bind Mount | 低い | 指定したホストパスが存在しないと動かない |

### 使い分け

| 用途 | 推奨 |
|------|------|
| DBデータ（本番） | Named Volume |
| 開発時のソースコード | Bind Mount |
| 設定ファイル（開発時） | Bind Mount |

参照: [`dev_docs/0413_docker-volume-learning.md`](0413_docker-volume-learning.md)

**正解：**
Named volume は Docker が名前で管理し、データは通常ホストの Docker 領域（例: `/var/lib/docker/volumes/<volume>/_data`）に置かれる。bind mount はホスト上の**指定パス**がそのままマウントされ、パスは利用者が責任を持つ。移植性では named volume はホストパスに依存しにくく、bind は環境ごとにパスが異なると壊れやすい。DB 永続化には named、開発中のソース反映には bind がよく使われる、という整理でよい。

**解説：**
表形式の整理と使い分けは的確。補足: いずれもホストのストレージ上に実体があるが、**誰がパスとライフサイクルを決めるか**（Docker vs 利用者）が対比の核心。

**一次資料：**
- [Use volumes | Docker Docs](https://docs.docker.com/storage/volumes/)
- [Volumes top-level element | Compose file reference](https://docs.docker.com/reference/compose-file/volumes/)

---

## Q2. `driver_opts` の `type: none` / `device:` / `o: bind`

Compose の `volumes` 定義で、次のような `driver_opts` が使われることがあります。

```yaml
volumes:
  example_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/username/data
```

`type: none`、`o: bind`、`device:` はそれぞれ何を指定していると考えられますか。また、この定義は **bind mount に近い挙動**を volume 名でラップしている、という理解でよいか、自分の言葉で説明してください。


### 自分の回答

次のように並び替えて説明する。

```yaml
volumes:
  example_data:
    driver: local  # ホストOS（Linuxカーネル）のmount機能を直接利用する設定
    driver_opts:
      # 1. 【実体の特定】ホストOS上の、Docker管理外にある物理ディレクトリをソースに指定
      device: /home/username/data

      # 2. 【接続方法の指定】ホストのmount(8)にある「--bind」オプションを使用し、
      #    既存のディレクトリ構造をそのままコンテナにマッピング（再配置）する
      o: bind

      # 3. 【型定義のスキップ】
      #    device（ホスト側のパス）は既に特定のファイルシステム（ext4等）として存在している。
      #    ここで別の型（tmpfsなど）を強制指定すると、マウント時のドライバ不適合によりエラーとなる。
      #    そのため、既存のファイルシステムの性質をそのまま引き継ぐ「none」を指定する。
      type: none
```

この設定の順序には私の理解を反映させている。まず `device` でホスト上の実体（ソース）を特定し、次に `o: bind` でホストOS（Ubuntu）のカーネル機能である `mount --bind` を呼び出すよう指示し、最後にそれゆえにファイルシステムの型指定が不要であるという意味で `type: none` としている。これらはすべてホスト側の `man 8 mount` の仕様に基づいた定義である。

で確認
```sh
docker run --rm -it alpine:3.21 sh -c "apk add mandoc man-pages util-linux-doc less && export PAGER=less && man 8 mount; sh"
```
---

### `driver_opts` について

`driver_opts` は `docker volume create --opt` の `--opt` 引数のリストに対応する。

---

### `name:` を指定しないことについて

`name:` を指定しないことで、Docker Compose の標準的な命名規則（プロジェクト名＋ボリューム名）に任せ、プロジェクトのポータビリティ（移植性）を保つ。

具体的には、トップレベルの `volumes:` 直下で定義された `example_data` が、このプロジェクトにおけるボリュームの識別子（Key）として機能し、Docker Compose はデフォルトで、この識別子にプロジェクト名（ディレクトリ名）を接頭辞として付与し、実体となるボリュームを自動的に作成・管理する。

本問の場合、`example_data` という volume 識別子から（`name:` プロパティで明示していないので）`[プロジェクト名]_example_data` という named volume が作成される。

---

### 「bind mount に近い挙動」について

トップレベルで bind mount されたボリュームを、配下のコンテナから名前付きボリュームとして呼び出すことになるため、bind mount に近い挙動を volume 名でラップしていると言える。

ここで「近い」というのは、以下の点で完全な bind mount（サービスレベルで直接定義する bind mount）と異なるためである：

| 観点 | サービスレベルの bind mount | driver_opts による volume |
|------|---------------------------|--------------------------|
| 定義場所 | `services.*.volumes` に直接書く | トップレベル `volumes:` で定義 |
| `docker volume ls` | 表示されない | 表示される |
| ライフサイクル | コンテナと共に管理される | `docker compose down -v` または `docker volume rm` で明示的削除が必要 |
| 複数サービスでの共有 | 各サービスで同じパスを書く必要あり | volume 名で参照できる |

一方、以下の点は bind mount と同一である：

- データの実体がホストの指定パス（`/home/username/data`）に置かれる
- Docker 管理下の `/var/lib/docker/volumes/` には格納されない

---

### 参考にしたページ

- [Volumes top-level element | Compose file reference](https://docs.docker.com/reference/compose-file/volumes/)
- [docker volume create — driver-specific options](https://docs.docker.com/reference/cli/docker/volume/create/)

**正解：**
`device:` はマウント元となる**ホスト上のパス**を指す。`o: bind` は `mount(8)` における bind mount を指定する。`type: none` は `local` ドライバと組み合わせ、追加のファイルシステム種別を立てずに bind する際に用いられる（ドキュメント・実装では `driver_opts` が `docker volume create` の `-o` に相当）。トップレベルで named volume として定義しつつ中身はホストの特定ディレクトリへの bind なので、「bind に近い挙動を volume 名でラップする」理解でよい。Compose では `name:` を省略すると `プロジェクト名_キー名` などの規則で volume が作られる。

**解説：**
`man mount` まで踏み込んだ整理は十分。YAML 内のキー記述順は**意味の順序と一致しない**ことがある点だけ注意（実行時はマウントオプション全体として解釈される）。サービス直下の bind と比較した表（`docker volume ls`・ライフサイクル・共有のしやすさ）は秀逸。

**一次資料：**
- [Volumes top-level element | Compose file reference](https://docs.docker.com/reference/compose-file/volumes/)
- [docker volume create — driver-specific options](https://docs.docker.com/reference/cli/docker/volume/create/)

---

## Q3. Compose file secrets の仕組み（Swarm なし）

Docker Compose で **トップレベルの `secrets:`** と **サービスへの `secrets:` 割り当て**を使う場合（クラシック Compose / Compose V2、**Swarm を使わない**前提）、次を説明してください。

- シークレットのソース（例: `file:`）からコンテナ内のどこにどのように渡されるか
- コンテナ内でシークレットを読むときの典型的なパス
- ドキュメント上、Compose の secrets が Swarm の secrets とどう位置づけられているか（混同しやすい点があれば一言）

**自分の回答：**
```bash
vagrant@vagrant:~$ docker compose version
Docker Compose version v5.1.2
```
- まず、Swam は本番環境でのDockerプロジェクトを複数の物理マシンを跨いだクラスター上で管理するオーケストレータである。
- 今回のInceptionは課題書の[Mandatory]の冒頭に`This project consists of having you set up a small infrastructure composed of different
services under specific rules. The whole project has to be done in a virtual machine. You have to use docker compose.`と明記されている
- docker-compose.ymlの開発環境としてのコンテナ管理ツールとしてComposeを用いて「Infrastructure as Code (IaC)」の体験を学習することに主眼が置かれている
以上を前提で回答する

- Docker Compose（非Swarm）におけるシークレットは、ホスト上のソースファイル（`: file:`で定義される）を`コンテナ内の/run/secrets/`配下に`<secret_name>`として読み取り専用でマウントする仕組み

- Swarm secrets (https://docs.docker.com/engine/swarm/secrets/) には：` Secrets are encrypted during transit and at rest in a Docker swarm.`と暗号化が明記されている
- 一方、coposeについては`Secrets are mounted as a file in /run/secrets/<secret_name> inside the container. docker` という記述は https://docs.docker.com/compose/how-tos/use-secrets/ にあるが、暗号化については述べられていない

- Swarm の secrets については下記のブログから推測すると、Docker compose のsecretsプロパティと異なり
	- パスワードファイルは暗号化される
	- Docker Swamの管理用データベースに暗号化されて保管されている（composeではホストのbind moun元に平文で置かれている）

参考[https://docs.docker.jp/compose/compose-file/#secrets-top-level-element]

[https://oneuptime.com/blog/post/2026-01-16-docker-secrets-swarm-compose/view#:~:text=stack.yml%20myapp-,Secrets%20in%20Docker%20Compose%20(Development),re%20bind%2Dmounted%20files]


**正解：**
非 Swarm の Compose では、`file:` ソースのシークレットはコンテナ内 **`/run/secrets/<secret_name>`** に（通常は読み取り専用で）マウントされる。Swarm の secrets はクラスタ全体での配布・暗号化（転送中・保管）などがドキュメントの主眼になりうる。Compose 開発向けの file ベースは**ホスト上のファイルをコンテナに渡す**モデルであり、Swarm と同じ「暗号化ストア」として扱わないのが混同ポイント。

**解説：**
課題文（Mandatory の compose）に合わせた前提整理と、公式に基づく `/run/secrets/` の説明は正しい。Swarm と Compose の差（暗号化の記述の有無）はレビューで聞かれやすい。一次資料は可能な限り **Docker 本家ドキュメント**を優先するとよい。

**一次資料：**
- [Use secrets in Compose | Docker Docs](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Secrets top-level element | Compose file reference](https://docs.docker.com/reference/compose-file/secrets/)

---

## Q4. 環境変数と secrets の見え方（inspect・ログ）

機密値を **環境変数** で渡す場合と、**Compose secrets** でファイルとして渡す場合について、`docker inspect` やプロセスの環境一覧から見たときの **露出のしやすさ**の違いを、定性的に説明してください（「どちらがレビューで指摘されやすいか」レベルでよい）。

**自分の回答：**
環境変数はホストからは
```bash
docker inspect <container_id> --format '{{json .Config.Env}}'
```
でコンテナ内でも`printenv`や`cat /proc/1/environ`で簡単に見れる。
Compose secretsでファイルとして渡すと、誰にどう見せるかはファイルシステムで管理できる。（デフォルトでは見れない）

**正解：**
環境変数は `docker inspect` の `Config.Env`、コンテナ内の `/proc/*/environ`、`printenv` などで**プロセス環境として露出しやすい**。secrets（ファイルマウント）は値そのものは環境変数に載らないが、`docker inspect` の **Mounts** にはマウント事実やパスが載るため「完全に不可視」ではない。レビューでは、平文を env に載せない・ログに出さない、が典型の指摘になる。

**解説：**
「env は inspect で一覧しやすい」は正しい。secrets 側は **ファイル権限・マウント情報・コンテナ内での cat の可否**まで含めて設計する、と補足するとより実務に近い。

**一次資料：**
- [Use secrets in Compose | Docker Docs](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Environment variables in Compose | Docker Docs](https://docs.docker.com/compose/how-tos/environment-variables/)

---

## Q5. `healthcheck` の主なキー

`docker-compose.yml` の `healthcheck` ブロックについて、次の各キーの**役割**を簡潔に説明してください: `test`, `interval`, `timeout`, `retries`, `start_period`。

※ **本課題の提出 compose には healthcheck を書かない方針**ですが、レビューやドキュメント読解のために構文を知っておく設問です。

**自分の回答：**

順に、ヘルスチェックを行うコマンド、実行間隔、コマンドの最大実行時間、これを超えると失敗判定、異常と判断されるまでの連続失敗回数、起動からヘルスチェックを行うまでの待ち時間
- 参考[https://docs.docker.jp/engine/reference/builder.html#builder-healthcheck]

**正解：**
- `test`: ヘルス判定に使うコマンドまたは CMD-SHELL 形式のシェルコマンド。
- `interval`: チェックの実行間隔。
- `timeout`: 1 回の `test` が失敗とみなされるまでの時間上限。
- `retries`: **連続で失敗**した回数がこの回数に達すると unhealthy と判定される（閾値）。
- `start_period`: 起動直後の猶予期間。この間は失敗しても unhealthy にカウントしない（アプリ起動待ち）。

**解説：**
`retries` を「異常と判断されるまでの連続失敗回数」という理解でよい。`timeout` は「コマンドの最大実行時間」と説明した部分は近いが、公式には「何秒でその試行を失敗にするか」のニュアンス。提出 compose では healthcheck を使わない方針だが、読み取りレビュー用の知識として有用。

**一次資料：**
- [Services — healthcheck | Compose file reference](https://docs.docker.com/reference/compose-file/services/#healthcheck)

---

## Q6. `depends_on` と `condition:`

Compose の `depends_on` について説明してください。

1.  `depends_on` だけ**（`condition` なし）のとき、Docker が**保証する範囲**は何か（「DB が接続可能になった」ことまで保証されるか）
2. `depends_on` に `condition: service_healthy` や `service_completed_successfully` を付けられる文脈（**どの Compose バージョン / 書式**で記述されるか、概要レベルでよい）
3. 本課題で healthcheck を採用しない場合、**WordPress が DB 起動を待つ**ためにアプリ側で何が必要か（一言）

**自分の回答：**
1. `depends_on`のみだと保証する範囲は依存元のサービスが`run`または`start`で起動していることのみ
2. `condition: service_healthy`をつけるには依存元のサービスが`healthcheck`を行っている時のみ（してないと無限に待たされるかは不明）
	- [https://docs.docker.jp/compose/compose-file/index.html#depends-on] 
3. WordPressがDBを呼び出す前に`mariadb-admin ping -h databasehost`成功まで起動確認、規定回数の後タイムアウト

**正解：**
1. `depends_on`（条件なし）は**コンテナの起動順**を制御するが、依存先が「接続可能」になるまで**保証しない**（DB の準備完了は保証されない）。
2. `condition: service_healthy` 等は **Compose file format 3.x** の長い形式の `depends_on` で記述される（実装・バージョンにより要確認だが、公式は compose ファイルの `depends_on` 拡張として説明）。
3. healthcheck を使わない場合は、**アプリの entrypoint で DB への接続確認（例: `mariadb-admin ping`）とタイムアウト**が必要。

**解説：**
1・3 は意図どおり。2 について `service_healthy` には依存先に `healthcheck` が必要（なければ期待どおりに動かない可能性）。日本語 mirror（docs.docker.jp）は補助可、一次は英語公式を推奨。

**一次資料：**
- [Services — depends_on | Compose file reference](https://docs.docker.com/reference/compose-file/services/#depends_on)

---

## Q7. Bridge ネットワークの基本

Docker の **bridge ドライバ**（デフォルト bridge と、ユーザー定義 bridge）について、次を説明してください。

1. 同一 bridge 上のコンテナ同士が **コンテナ名・サービス名で名前解決できる**理由（ざっくり）
2. デフォルト bridge とユーザー定義 bridge の違いのうち、**Compose でサービスを繋ぐ**ときに重要な点を1つ以上

**自分の回答：**

1.　DockerのDNSシステムが機能するから
2.　ユーザー定義bridgeネットワークにRun Service内で接続する必要がある、一旦サービスを起動してからだと、その時点でデフォルトbridgeに繋がるので、のちにユーザー定義bridgeに繋ぎかえるのは困難。

**正解：**
1. ユーザー定義 bridge 上では Docker の**埋め込み DNS**により、コンテナ名や Compose の**サービス名**が名前解決される（`docker network` のスコープ内）。
2. Compose は通常プロジェクト用の**ユーザー定義ネットワーク**を作り、サービスをそこに接続する。デフォルト `bridge` はコンテナを `--link` なしで名前解決しにくい等の違いがあり、**Compose でサービス名で通信する**ならユーザー定義側が前提になりやすい。

**解説：**
「DNS があるから」は方向性は合うが、**どのネットワーク上か**（ユーザー定義 vs デフォルト bridge）をセットで言えるとより正確。Q2 の「起動後に差し替えが困難」は一部場面でそうだが、Compose 管理下では最初からプロジェクトネットワークに載る想定が一般的。再読: [Networking in Compose](https://docs.docker.com/compose/how-tos/networking/)。

**一次資料：**
- [Bridge network driver | Docker Docs](https://docs.docker.com/engine/network/drivers/bridge/)
- [Networking in Compose | Docker Docs](https://docs.docker.com/compose/how-tos/networking/)

---

## Q8. `restart` ポリシー

Compose の `restart:` に `always` を指定したときの動作を説明してください。参考として `no`, `unless-stopped`, `on-failure` との**違いの要点**（いつ再開しないか）も一言ずつ。

**自分の回答：**
日本語公式[https://docs.docker.jp/compose/compose-file/index.html#restart]と
[https://qiita.com/fukushun-ka/items/3432f79a5229534398cc]によると
- `always` ：コンテナを削除されたのちは再開しない。（削除しない限り再開する。）
- `no` ：プロジェクトの再起動までサービスを再開しない。
- `on-failure` ：正常終了なら再開しない。（コンテナの終了コードがエラーを示す場合、コンテナを再開）
- `unless-stopped` ：サービスが停止（`on-failure`と違い手動で`docker stop`や`docker-compose down`でコンテナを終了させて状態）もしくは削除する場合は再開しない。(ユーザーが止めるまで再開)


**正解：**
- `no`: **自動再起動しない**（プロセスが終了しても再起動しない）。
- `always`: 終了コードに関わらず**常に再起動**（手動 `docker stop` したコンテナは、デーモン再起動後など挙動に注意。コンテナ削除後はその ID では復活しない）。
- `on-failure`: **非ゼロ終了コード**のときのみ再起動。
- `unless-stopped`: 手動で停止するまで再起動するが、`always` との差は**デーモン再起動時**の扱いなど（公式の対比表を参照）。

**解説：**
`no` を「プロジェクト再起動まで再開しない」とすると誤り（単に自動再起動なし）。`always` / `unless-stopped` の違いは一文では紛らわしいので、[Compose の restart 一次資料](https://docs.docker.com/reference/compose-file/services/#restart) の表に照らして整理し直すとよい。

**一次資料：**
- [Services — restart | Compose file reference](https://docs.docker.com/reference/compose-file/services/#restart)

---

## Q9. `.env` と secrets の使い分け（本リポジトリ方針）

`phase_plan.md` にある方針に沿って、次を答えてください。

- `srcs/.env` に書いてよい情報の例（機密を含まないもの）
- `secrets/` に置くファイルの例と、Git に含めない理由
- MariaDB や WordPress の entrypoint で、シークレットを **環境変数に export するか / そのままファイルを読むか**は、実装の都合で様々だが、**課題の「Docker secrets 推奨」**に応えるときに注意すべき点（自分の言葉で）

**自分の回答：**

## .env と secrets の役割分担

| 項目 | 管理方法 | Git に含めるか | 例 |
|------|----------|---------------|-----|
| ドメイン名 | `.env` | はい | `DOMAIN_NAME=login.42.fr` |
| MySQL ユーザー名 | `.env` | はい | `MYSQL_USER=wp_user` |
| MySQL データベース名 | `.env` | はい | `MYSQL_DATABASE=wordpress` |
| MySQL パスワード | Docker Secrets | いいえ | `secrets/db_password.txt` |
| MySQL root パスワード | Docker Secrets | いいえ | `secrets/db_root_password.txt` |
| WordPress 管理者 credentials | Docker Secrets | いいえ | `secrets/credentials.txt` |

根拠
API keysは今回の実装で使わないので、confidential informationは
`passowords` と`credential`のみ

課題書８ページ
`No password must be present in your Dockerfiles.`
Dokerfile内には書けない
`It is mandatory to use environment variables.`

`Also, it is mandatory to use a .env file to store environment variables.`
なので`passowords`と``credential``以外の環境変数は`srcs/.env`に収める必要がある
` It is strongly recommended that you use Docker secrets to store any confidential information.`
より`passowords`のみ`secrets/`に置く必要がある。

`Any credentials, API keys,or passwords found in your Git repository (outside of properly configured secrets) will result in project failure.`
を根拠に`secrets/`に置くファイルはGitに含めてはならない

**正解：**
- `.env`: ドメイン名、DB 名、非機密のユーザー名など（`phase_plan.md` の列挙どおり）。**パスワード類は secrets 側**。
- `secrets/`: `db_password.txt` 等、機密のファイル。**`.gitignore` で除外**し、リポジトリに残さない（課題失敗要件）。
- entrypoint では **`/run/secrets/<name>` を読み**、必要なら一時的に環境変数へ展開するか、アプリがファイルを直接読むかは実装次第だが、**Dockerfile に平文を書かない**・**git に機密を含めない**が必須。

**解説：**
課題書の mandatory（`.env` 必須・secrets 強く推奨・リポジトリに認証情報なし）との対応が取れている。表の `credentials.txt` は `phase_plan.md` の **`wp_admin_password.txt`** 等のファイル名と揃えると提出物と一致しやすい。タイポ `passowords` はドキュメント修正推奨。

**一次資料：**
- [Use secrets in Compose | Docker Docs](https://docs.docker.com/compose/how-tos/use-secrets/)
- （課題書）`dev_docs/subject_ja.md` 該当節

---

## Q10. 統合イメージ（Inception）

NGINX・WordPress（PHP-FPM）・MariaDB の3サービスを Compose で起動するとき、**TLS 終端**、**FastCGI**、**DB 接続**の流れを、コンテナ名・ポート・ネットワークの観点から1段落で説明してください（正確なポート番号まで書ければ尚可）。

**自分の回答：**
ホストマシンのlocalhostとのHTTPプロトコルはTLS終端で接続されたnginxとFastCGIプロトコルをDocker networkでポート9000で接続されたwordpressとMySQLプロトコルでDocker network のポート3306でmariadbと接続される

**正解：**
例: ブラウザは **HTTPS（443）** で nginx に接続し、TLS 終端は nginx。PHP 動的リクエストは nginx が **FastCGI（通常 WordPress コンテナの PHP-FPM `:9000`）** に転送。WordPress（PHP）が DB へは同一 Compose ネットワーク上で **MariaDB の 3306/tcp**（サービス名をホスト名として）に接続する、という流れ。

**解説：**
「TLS 終端」「FastCGI」「DB」の三要素は含まれている。ホストからは `https://...:443` で nginx に届き、**HTTP と TLS の関係**（平文 HTTP で nginx に入るとは限らない—本課題は 443）を一文で区別するとより明確。MySQL/MariaDB プロトコルで 3306 と述べる点は良い。

**一次資料：**
- [Networking in Compose | Docker Docs](https://docs.docker.com/compose/how-tos/networking/)
- [NGINX FastCGI モジュール](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)（フェーズ2の復習として）

---

## 採点サマリ（記述 10 問）

| 観点 | 問 |
|------|-----|
| 一次資料・構造が特に良好 | Q1, Q2, Q3, Q6 |
| 正しいが解説で補足した点 | Q4（マウント情報の可視性）, Q5（`retries` / `start_period`）, Q7（デフォルト bridge と Compose の違い）, Q9（ファイル名を `phase_plan` に揃える）, Q10（HTTPS/443 の明示） |
| 用語の再確認を推奨 | Q8（`no` は「再起動しない」— プロジェクト再起動とは無関係。`always` / `unless-stopped` は公式表で対比） |

復習の優先度が高いのは **Q8** と、**Q7**（ユーザー定義ネットワークと埋め込み DNS）です。
