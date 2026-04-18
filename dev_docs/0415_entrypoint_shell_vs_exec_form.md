# Dockerfile ENTRYPOINT: shell form vs exec form

日付: 2025-04-15

---

## 概要

Dockerfile の `ENTRYPOINT`（および `CMD`）には2つの記法がある。
この違いは PID 1 問題やシグナル伝搬に直結する重要な知識。

---

## 2つの記法

### exec form（推奨）

```dockerfile
ENTRYPOINT ["mariadbd", "--user=mysql"]
```

- JSON 配列形式
- Docker が直接 `execve()` でコマンドを実行
- **`/bin/sh` は介在しない**
- 指定したコマンドが **直接 PID 1** になる

### shell form

```dockerfile
ENTRYPOINT mariadbd --user=mysql
```

- 文字列形式
- Docker が内部的に `/bin/sh -c "mariadbd --user=mysql"` に変換
- **`/bin/sh` が PID 1** になり、実際のコマンドは子プロセス

---

## プロセス構造の違い

### exec form

```
コンテナ起動
    ↓
PID 1: mariadbd --user=mysql  ← 最初から mariadbd が PID 1
```

### shell form

```
コンテナ起動
    ↓
PID 1: /bin/sh -c "mariadbd --user=mysql"
    ↓ (sh が子プロセスとして起動)
PID 7: mariadbd --user=mysql
```

---

## なぜ shell form は問題か

| 観点 | shell form | exec form |
|------|------------|-----------|
| PID 1 | `/bin/sh` | 指定したコマンド |
| `docker stop` のシグナル | `/bin/sh` で止まる（子に届かない） | 直接届く |
| グレースフルシャットダウン | 不可（10秒後に SIGKILL） | 可能 |

---

## exec form の制約

exec form は `execve()` で直接実行するため、**シェルの機能が使えない**:

| 機能 | exec form | shell form |
|------|-----------|------------|
| パイプ `\|` | 使えない | 使える |
| リダイレクト `>` `<` | 使えない | 使える |
| 環境変数展開 `$VAR` | 使えない | 使える |
| ワイルドカード `*` | 使えない | 使える |

### minishell との対比

exec form は「`execve()` だけを持つ minishell」と同じ。
パイプやリダイレクト、変数展開を実装する前の状態。

---

## 解決パターン: exec form + シェルスクリプト + exec

シェル機能と PID 1 問題を両立させる定番パターン:

### Dockerfile

```dockerfile
ENTRYPOINT ["/entrypoint.sh"]  # exec form でスクリプトを指定
```

### entrypoint.sh

```bash
#!/bin/sh
# シェルスクリプト内ではシェル機能が使える
echo "Starting with database: $MARIADB_DATABASE"

# 最後に exec で PID 1 を譲る
exec mariadbd --user=mysql
```

### 動作の流れ

```
1. Docker が exec form で /entrypoint.sh を直接実行
   → PID 1: /entrypoint.sh

2. entrypoint.sh 内でシェル機能（$VAR 展開など）を使用

3. exec mariadbd で entrypoint.sh 自身を mariadbd に置き換え
   → PID 1: mariadbd（entrypoint.sh は消滅）
```

---

## まとめ

| 要素 | 役割 |
|------|------|
| exec form `["cmd"]` | シェルを介さず直接実行、PID 1 問題を回避 |
| entrypoint.sh | シェル機能（環境変数展開など）を使う場所 |
| `exec mariadbd` | シェルスクリプトから PID 1 を引き継がせる |

この3つの組み合わせで「シェル機能」と「正しい PID 1」を両立する。

---

## 参考

- [Docker 公式 - ENTRYPOINT](https://docs.docker.com/reference/dockerfile/#entrypoint)
- [Docker 公式 - Shell and exec form](https://docs.docker.com/reference/dockerfile/#shell-and-exec-form)
- `dev_docs/0408_docker_exec_execve.md`（exec と execve() の関係）
