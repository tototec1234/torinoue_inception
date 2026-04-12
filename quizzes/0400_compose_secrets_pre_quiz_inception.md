# フェーズ4 事前クイズ - Docker Compose ・ secrets 編

> 作成日: 2026-04-12
> 対象フェーズ: 4（Docker Compose 統合 + secrets）
> 実施タイミング: フェーズ4 開始前（タスク 4-2 `docker-compose.yml` 実施前）
> 採点日: （未実施）

本ファイルは `phase_plan.md` の「クイズ運用ルール」**ステップ1**に従い、**問題文・一次資料**と **「自分の回答」欄**のみを含みます。**正解・解説**は、ドライバーが回答を埋めたあと、採点時に追記します。

**本課題の方針メモ（`phase_plan.md` より）:** 課題書に healthcheck の明示がないため、**提出物の `docker-compose.yml` には healthcheck を書かない**。`depends_on` と **entrypoint 側の DB 待機**で起動順・可用性を担保する。以下の healthcheck 関連の設問は**理解確認用**です。

---

## Q1. Named volume と bind mount の違い

Docker のデータ永続化において、**named volume（名前付きボリューム）**と **bind mount** の違いを、次の観点で説明してください。

- データの実体がどこに置かれるか（誰がパス・ライフサイクルを管理するか）
- ホストのディレクトリ構成への依存の強さ（移植性）
- 一般的な使い分けの例（DB データ、設定ファイルの開発時マウントなど）

**自分の回答：**
（ここに記入）

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

**自分の回答：**
（ここに記入）

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
（ここに記入）

**一次資料：**
- [Use secrets in Compose | Docker Docs](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Secrets top-level element | Compose file reference](https://docs.docker.com/reference/compose-file/secrets/)

---

## Q4. 環境変数と secrets の見え方（inspect・ログ）

機密値を **環境変数** で渡す場合と、**Compose secrets** でファイルとして渡す場合について、`docker inspect` やプロセスの環境一覧から見たときの **露出のしやすさ**の違いを、定性的に説明してください（「どちらがレビューで指摘されやすいか」レベルでよい）。

**自分の回答：**
（ここに記入）

**一次資料：**
- [Use secrets in Compose | Docker Docs](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Environment variables in Compose | Docker Docs](https://docs.docker.com/compose/how-tos/environment-variables/)

---

## Q5. `healthcheck` の主なキー

`docker-compose.yml` の `healthcheck` ブロックについて、次の各キーの**役割**を簡潔に説明してください: `test`, `interval`, `timeout`, `retries`, `start_period`。

※ **本課題の提出 compose には healthcheck を書かない方針**ですが、レビューやドキュメント読解のために構文を知っておく設問です。

**自分の回答：**
（ここに記入）

**一次資料：**
- [Services — healthcheck | Compose file reference](https://docs.docker.com/reference/compose-file/services/#healthcheck)

---

## Q6. `depends_on` と `condition:`

Compose の `depends_on` について説明してください。

- **`depends_on` だけ**（`condition` なし）のとき、Docker が**保証する範囲**は何か（「DB が接続可能になった」ことまで保証されるか）
- `depends_on` に `condition: service_healthy` や `service_completed_successfully` を付けられる文脈（**どの Compose バージョン / 書式**で記述されるか、概要レベルでよい）
- 本課題で healthcheck を採用しない場合、**WordPress が DB 起動を待つ**ためにアプリ側で何が必要か（一言）

**自分の回答：**
（ここに記入）

**一次資料：**
- [Services — depends_on | Compose file reference](https://docs.docker.com/reference/compose-file/services/#depends_on)

---

## Q7. Bridge ネットワークの基本

Docker の **bridge ドライバ**（デフォルト bridge と、ユーザー定義 bridge）について、次を説明してください。

- 同一 bridge 上のコンテナ同士が **コンテナ名・サービス名で名前解決できる**理由（ざっくり）
- デフォルト bridge とユーザー定義 bridge の違いのうち、**Compose でサービスを繋ぐ**ときに重要な点を1つ以上

**自分の回答：**
（ここに記入）

**一次資料：**
- [Bridge network driver | Docker Docs](https://docs.docker.com/engine/network/drivers/bridge/)
- [Networking in Compose | Docker Docs](https://docs.docker.com/compose/how-tos/networking/)

---

## Q8. `restart` ポリシー

Compose の `restart:` に `always` を指定したときの動作を説明してください。参考として `no`, `unless-stopped`, `on-failure` との**違いの要点**（いつ再開しないか）も一言ずつ。

**自分の回答：**
（ここに記入）

**一次資料：**
- [Services — restart | Compose file reference](https://docs.docker.com/reference/compose-file/services/#restart)

---

## Q9. `.env` と secrets の使い分け（本リポジトリ方針）

`phase_plan.md` にある方針に沿って、次を答えてください。

- `srcs/.env` に書いてよい情報の例（機密を含まないもの）
- `secrets/` に置くファイルの例と、Git に含めない理由
- MariaDB や WordPress の entrypoint で、シークレットを **環境変数に export するか / そのままファイルを読むか**は、実装の都合で様々だが、**課題の「Docker secrets 推奨」**に応えるときに注意すべき点（自分の言葉で）

**自分の回答：**
（ここに記入）

**一次資料：**
- [Use secrets in Compose | Docker Docs](https://docs.docker.com/compose/how-tos/use-secrets/)
- （課題書）`dev_docs/subject_ja.md` 該当節

---

## Q10. 統合イメージ（Inception）

NGINX・WordPress（PHP-FPM）・MariaDB の3サービスを Compose で起動するとき、**TLS 終端**、**FastCGI**、**DB 接続**の流れを、コンテナ名・ポート・ネットワークの観点から1段落で説明してください（正確なポート番号まで書ければ尚可）。

**自分の回答：**
（ここに記入）

**一次資料：**
- [Networking in Compose | Docker Docs](https://docs.docker.com/compose/how-tos/networking/)
- [NGINX FastCGI モジュール](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)（フェーズ2の復習として）
