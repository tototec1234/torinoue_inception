# セッションログ #0014

> 日付: 2026-04-09
> セッション種別: トラブルシューティング（`vagrant up` 失敗 → 原因特定 → 解消）
> 対応フェーズ: インフラ（VM環境構築）
> 開始: 2026-04-09 21:30 頃
> 終了: 2026-04-09 22:40 頃

---

## 事象

`vagrant up` を実行すると、VirtualBox の VM が `aborted` または `poweroff` 状態になり、SSH 接続まで到達できない。

```
==> default: Booting VM...
==> default: Waiting for machine to boot. This may take a few minutes...
The guest machine entered an invalid state while waiting for it
to boot. Valid states are 'starting, running'. The machine is in the
'poweroff' state.
```

---

## 原因

### 直接原因: ホストマシンのメモリ枯渇（OOM）

```
$ free -h
               total        used        free      shared  buff/cache   available
Mem:            15Gi        14Gi       357Mi       292Mi       837Mi       547Mi
Swap:          4.0Gi       2.8Gi       1.2Gi
```

- ホスト合計 15GB のうち **14GB が使用済み、空き 357MB**
- Swap も 4GB 中 2.8GB 使用
- VM が起動（1024〜4096MB 要求）→ Linux OOM killer が `VBoxHeadless` を kill → `poweroff` / `aborted`

### 根本原因: ゾンビ VBoxHeadless プロセスの蓄積

過去の `vagrant up` 失敗のたびに `VBoxHeadless` プロセスが終了されずに残り続けた。

```
$ ps aux --sort=-%mem | head -20
```

で確認したところ、**VBoxHeadless が 14 プロセス** 残存（各 500〜760MB、合計約 8GB）。

`vagrant destroy` や `VBoxManage unregistervm --delete` で VM 定義は消えても、対応する VBoxHeadless プロセスは自動停止しないケースがあり、メモリを占有し続けていた。

### 副次的問題: Vagrantfile の provider 指定ミス

元の Vagrantfile で provider が `vmware_fusion` だったため、`--provider=virtualbox` で起動しても memory/cpus 設定が VirtualBox に適用されていなかった。

```ruby
# 元（vmware_fusion → VirtualBox には効かない）
config.vm.provider "vmware_fusion" do |vf|
  vf.memory = "4096"
  vf.cpus = 2
end

# 修正後
config.vm.provider "virtualbox" do |vb|
  vb.memory = "1024"
  vb.cpus = 2
end
```

---

## 解消手順

### Step 1: ゾンビ VBoxHeadless プロセスを全停止

```bash
killall VBoxHeadless
sleep 5
free -h          # メモリが回復したことを確認
```

### Step 2: VirtualBox に残っている VM を全削除

```bash
VBoxManage list vms
# 表示された全 UUID に対して:
VBoxManage unregistervm <UUID> --delete
```

### Step 3: Vagrant の管理情報をリセット

```bash
cd ~/tmp/0409inception/srcs/vm
rm -rf .vagrant
vagrant global-status --prune
```

### Step 4: Vagrantfile を修正

provider を `virtualbox` に変更し、メモリを 1024MB に設定:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.network "forwarded_port", guest: 443, host: 443, host_ip: "127.0.0.1"
  config.vm.synced_folder "../../", "/vagrant"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
    vb.cpus = 2
  end

  config.vm.provision "shell", path: "init.sh", privileged: false
end
```

### Step 5: vagrant up

```bash
free -h          # 起動前にメモリ空きを確認（数GB 空いていること）
vagrant up --provider=virtualbox
vagrant status   # running であることを確認
vagrant ssh
```

---

## トラブルシューティングガイド

### `vagrant up` で `aborted` / `poweroff` になったときの切り分けフロー

```
vagrant up 失敗
  │
  ├─ 1) ゾンビプロセス確認
  │     $ ps aux | grep VBoxHeadless
  │     → 不要なプロセスがあれば killall VBoxHeadless
  │
  ├─ 2) メモリ確認
  │     $ free -h
  │     → available が VM の vb.memory 以下なら、
  │       不要アプリを閉じるか vb.memory を下げる
  │
  ├─ 3) VirtualBox 単体で起動テスト
  │     $ VBoxManage startvm <UUID> --type headless
  │     $ sleep 10
  │     $ VBoxManage showvminfo <UUID> --machinereadable | grep VMState
  │     → "running" なら VM 自体は正常（Vagrant/メモリ側の問題）
  │     → "poweroff"/"aborted" なら VBox ログを確認:
  │       $ VBoxManage showvminfo <UUID> --log 0 | grep -E "VERR_|Guru|panic|POWERING_OFF"
  │
  ├─ 4) Vagrantfile の provider ブロック確認
  │     → virtualbox を使うなら provider "virtualbox" であること
  │     → vmware_fusion ブロックでは memory/cpus が VirtualBox に適用されない
  │
  └─ 5) Vagrant 管理情報の不整合
        $ rm -rf .vagrant
        $ vagrant global-status --prune
        → 管理情報をリセットして再作成
```

### ゾンビプロセスを防ぐ運用ルール

| やること | コマンド |
|----------|----------|
| VM を止める | `vagrant halt` |
| VM を破棄する | `vagrant destroy -f` |
| 破棄後にプロセス残存確認 | `ps aux \| grep VBoxHeadless` |
| 残っていたら | `killall VBoxHeadless` |
| VBox 登録も掃除 | `VBoxManage list vms` → `VBoxManage unregistervm <UUID> --delete` |

### メモリ目安（42 校 15GB ホスト）

| 構成 | VM メモリ推奨 |
|------|---------------|
| Cursor + VM のみ | 1024〜2048 MB |
| Cursor + VM + Docker（inception） | 2048 MB（Cursor を閉じて起動推奨） |
| VM + Docker（Cursor なし） | 2048〜3072 MB |

### VirtualBox ログの取り方

```bash
# VM の UUID を確認
VBoxManage list vms

# ログ出力（0 が最新、1〜3 が過去）
VBoxManage showvminfo <UUID> --log 0 > vbox-log0.txt

# エラー行だけ抽出
grep -nE "VERR_|Guru|panic|fatal|POWERING_OFF|Machine state changed" vbox-log0.txt
```

---

## 学び

- **`vagrant up` 失敗 → 再試行** を繰り返すと、VBoxHeadless ゾンビが蓄積してメモリを食い尽くす悪循環に入る
- VirtualBox ログ（`--log 0`）にクラッシュ原因が無い場合は、**ホスト側（メモリ / プロセス）** を疑う
- `Vagrantfile` の provider ブロック名と実際に使う provider の一致を確認する
- 42 校の共有 PC（15GB RAM）では、重量級アプリ（Cursor, ブラウザ等）と VM の共存に注意が必要
