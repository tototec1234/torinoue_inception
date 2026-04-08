# su / runuser / sudo 比較メモ（学習用）

## 目的

`--allow-root` の是非を議論する本筋からは外れるが、  
ユーザー切り替えコマンドの挙動差を理解するための補助資料として記録する。

---

## 前提

- 検証対象イメージ: `alpine`, `debian:bookworm`
- 想定ユーザー: `nobody`
- `nobody` はログインシェルが `nologin` / `false` のことが多い

---

## 観察ポイント

### 1) su

- `su USER -c "cmd"` は、実装や対象ユーザーのシェル設定に影響されやすい
- Alpine（BusyBox `su`）と Debian（util-linux `su`）でオプション差がある
  - BusyBox: `-c`, `-s`
  - util-linux: `--command`, `--shell` も使える
- `nobody` がログイン不能シェルの場合、`su` は失敗しやすい

### 2) runuser

- 主に root 向けのユーザー切り替えコマンド
- Debian 系では使えることが多いが、最小 Alpine では入っていないことがある
- `runuser --user nobody -- whoami` のように実行できるケースがある

### 3) sudo

- `sudo --user nobody whoami` は、`su` と違って
  ターゲットユーザーのログインシェルを経由せずコマンド実行するため、
  `nobody` でも成功する場面がある
- ただし、イメージに `sudo` が入っていない場合は事前インストールが必要

---

## 今回の結論（資料としての位置付け）

- `su` は実装差（BusyBox / util-linux）とシェル設定の影響を受けやすい
- `runuser` / `sudo` は「代替手段」として有用だが、
  `--allow-root` の本論に混ぜると論点がブレる
- よって本編では `su` 周辺に絞り、`runuser` / `sudo` は補助資料として分離するのが適切

---

## 参考コマンド（再検証用）

```bash
for img in alpine debian:bookworm; do
  echo "========== Testing on: ${img} =========="
  docker run --rm --user root "${img}" /bin/sh -c '
    if [ -f /usr/bin/apt-get ]; then
      apt-get update --quiet
      apt-get install --yes --quiet sudo >/dev/null
    fi

    printf "%-20s" "[1. su default]"
    su nobody -c "whoami" 2>&1 || echo "FAILED"

    printf "%-20s" "[2. su with shell]"
    su -s /bin/sh nobody -c "whoami" 2>&1 || echo "FAILED"

    if command -v runuser >/dev/null; then
      printf "%-20s" "[3. runuser]"
      runuser --user nobody -- whoami 2>&1 || echo "FAILED"
    else
      echo "[3. runuser]        NOT INSTALLED"
    fi

    if command -v sudo >/dev/null; then
      printf "%-20s" "[4. sudo]"
      sudo --user nobody whoami 2>&1 || echo "FAILED"
    else
      echo "[4. sudo]           NOT INSTALLED"
    fi
  '
done