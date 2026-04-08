# Docker の `exec` と C言語の `execve()` の関係

日付: 2026-04-08

---

## 概要

Dockerの`ENTRYPOINT`スクリプトで使われる `exec` コマンドは、
Cのシステムコール **`execve(2)`（execファミリー）** と本質的に同じ動作をする。

---

## bashの `exec` とは

```bash
#!/bin/sh
exec ./my_app
```

- 新たにプロセスを生成（fork）**しない**
- 現在のプロセス（sh）を `./my_app` に**丸ごと置き換える**
- 内部的に `execve()` を呼んでいる

---

## minishell / ft_popen との比較

| 場面 | fork | exec |
|------|------|------|
| minishellの外部コマンド実行 | `fork()` してから | 子プロセスで `execve()` |
| ft_popen | `fork()` してから | 子プロセスで `execve()` |
| **Dockerの `exec app`** | **forkしない** | **現プロセス自身を `execve()` で置き換え** |

minishellをクリア済みであれば `execve()` は実装済みのはず。
ただしminishellでは「fork → 子でexec」が基本パターンだったのに対し、
Dockerでは **forkなしでexecのみ** という点が異なる。

---

## なぜ PID 1 が重要か

`docker stop` はコンテナの **PID 1 に SIGTERM** を送る。

```
# exec なし（悪い例）
PID 1: sh entrypoint.sh
PID 7: ./my_app   ← SIGTERMが届かない → 強制SIGKILL → graceful shutdownできない

# exec あり（良い例）
PID 1: ./my_app   ← SIGTERMが直接届く → graceful shutdown可能
```

minishellで `waitpid()` やシグナル処理を実装した経験があれば、
「シグナルが誰に届くか」の感覚はすでに身についているはず。

---

## execファミリーの整理

```c
execve(path, argv, envp);  // 最も基本。minishellで使った
execvp(file, argv);        // PATH検索あり版
execlp(file, arg0, ...);   // 可変長引数版
```

Dockerのshellスクリプトが呼ぶ `exec` は、内部的に `execve` 相当。

---

## 参考

- [Docker公式 ENTRYPOINT best practices](https://docs.docker.com/build/building/best-practices/#entrypoint)
- `man 2 execve`
