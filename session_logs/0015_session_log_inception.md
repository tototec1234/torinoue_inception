# セッションログ #0015

> 日付: 2026-04-10
> セッション種別: トラブルシューティング（`vagrant up` 失敗 → 原因特定 → ワークアラウンド確立）
> 対応フェーズ: インフラ（VM環境構築 — iMac環境での初回セットアップ）
> 環境: 42Tokyo 校舎 旧PC（ハードウェア: iMac / OS: Ubuntu / CPU: Intel i5-8500）
> 開始: 2026-04-10 02:30 頃
> 終了: 2026-04-10 04:50 頃

---

## 方針決定

- 校舎の新型PC（Dell + Ubuntu）での Inception 開発を断念（セッション#0014 で OOM 問題あり）
- 校舎の旧PC（iMac + Ubuntu）に切り替え
- 自宅では従来どおり M2 Mac で開発を継続

---

## 事象1: `vagrant up` で `NS_ERROR_INVALID_ARG`（import 失敗）

### 症状

```
VBoxManage: error: Appliance import failed
VBoxManage: error: Code NS_ERROR_INVALID_ARG (0x80070057)
```

OVF の解釈は成功するが、ディスク展開で失敗。

### 原因: `/home` のディスク容量不足

```
$ df -h /home/torinoue
/dev/sdb  9.4G  9.0G  321M  97% /home/torinoue
```

VirtualBox のデフォルト VM 保存先が `/home/torinoue/VirtualBox VMs/` だったため、
数 GB の VMDK 展開に必要な容量が不足していた。

### 解決策: VM 保存先を `/sgoinfre` に変更

```bash
mkdir -p /sgoinfre/torinoue/VirtualBox_VMs
VBoxManage setproperty machinefolder /sgoinfre/torinoue/VirtualBox_VMs
```

- `/sgoinfre`: 共有ストレージ（8TB中 2.3TB空き）、どの端末からもアクセス可能
- `/goinfre`: ローカルストレージ（高速だが席を変えると消える）
- ディレクトリ名はスペースを含まない `VirtualBox_VMs` を採用

### 副次的発見: Vagrant AppImage のライブラリ汚染

```
awk: symbol lookup error: /tmp/.mount_vagranH54e2z/usr/lib/libreadline.so.8: undefined symbol: UP
VBoxManage: /tmp/.mount_vagranH54e2z/usr/lib/libcurl.so.4: no version information available
```

Vagrant の AppImage（v2.4.0）がバンドルするライブラリが VBoxManage/VBoxHeadless に干渉。
`ENV['LD_LIBRARY_PATH'] = nil` や `VAGRANT_PREFER_SYSTEM_BIN=1` では解消しなかった。

---

## 事象2: `vagrant up` で `poweroff` 状態になる

### 症状

import 成功後、VM が起動するが Vagrant が `poweroff` と報告する。

```
The guest machine entered an invalid state while waiting for it
to boot. Valid states are 'starting, running'. The machine is in the
'poweroff' state.
```

### 切り分け結果

| 確認項目 | 結果 |
|----------|------|
| VBox ログ（`--log 0`） | VM は正常起動（Guest Additions 7.2.4 ロード、VBoxService 起動、NAT 動作） |
| ログ内のエラー | VERR_, Guru, panic, POWERING_OFF 等 **一切なし** |
| 手動起動 `VBoxManage startvm` | **成功、30秒後も running を維持** |
| メモリ | 15GB 中 10GB available（OOM ではない） |

### 結論

VM 自体は正常。**Vagrant の AppImage ライブラリ汚染により、Vagrant が VM 状態を正しく取得できない**のが原因。
`VMStateChangeTime` が `2025-10-23` という異常値を返す現象も確認。

### Vagrantfile の修正

- `--cpuidset` 行を削除（第14世代CPU向けハック、i5-8500 には不要かつ有害の可能性）
- `config.vm.network` を `provider` ブロックの外に移動（正しいスコープ）
- `config.vm.provision` を追加（init.sh 実行用）

---

## ワークアラウンド手順（iMac 環境）

Vagrant の根本問題（AppImage ライブラリ汚染）は未解決のため、手動で補完する運用。

### VM 作成（初回のみ）

```bash
cd ~/0409inception/srcs/vm
rm -rf .vagrant
vagrant up    # poweroff エラーで止まるが VM 自体は作成される
```

### 共有フォルダをプロジェクトルートに変更（初回のみ）

```bash
VM_NAME=$(VBoxManage list vms | head -1 | sed 's/"\(.*\)".*/\1/')
VBoxManage sharedfolder remove "$VM_NAME" --name vagrant
VBoxManage sharedfolder add "$VM_NAME" --name vagrant \
  --hostpath /home/torinoue/0409inception --automount
```

### VM 起動・接続

```bash
VM_NAME=$(VBoxManage list vms | head -1 | sed 's/"\(.*\)".*/\1/')
VBoxManage startvm "$VM_NAME" --type headless
sleep 15
ssh -p 2222 vagrant@127.0.0.1   # パスワード: vagrant
```

### ゲスト内セットアップ（起動ごとに必要）

```bash
sudo modprobe vboxsf
sudo mkdir -p /vagrant
sudo mount -t vboxsf vagrant /vagrant
```

### Docker インストール（初回のみ）

```bash
sudo bash /vagrant/srcs/vm/init.sh
exit
ssh -p 2222 vagrant@127.0.0.1   # グループ反映のため再ログイン
```

### VM 停止

```bash
# ゲスト内で
exit
# ホストで
VM_NAME=$(VBoxManage list vms | head -1 | sed 's/"\(.*\)".*/\1/')
VBoxManage controlvm "$VM_NAME" savestate
```

### ゾンビプロセス確認（習慣づける）

```bash
ps aux | grep VBoxHeadless
# 不要なプロセスがあれば: kill <PID>
```

---

## 最終状態

| 項目 | 状態 |
|------|------|
| VM (VirtualBox) | running（手動起動） |
| SSH | OK（`ssh -p 2222 vagrant@127.0.0.1`） |
| 共有フォルダ `/vagrant` | プロジェクトルート（`/home/torinoue/0409inception`）をマウント |
| Docker | 29.4.0 |
| Docker Compose | v5.1.2 |
| `vagrant up` 一発起動 | **未解決**（評価対応で要検討、残り約60時間） |

---

## 残課題

- [ ] **Vagrant の根本修正**（`vagrant up` 一発で動く状態にする）
  - Vagrant バージョンアップ（2.4.0 → 2.4.9）を試す
  - システムパッケージ版 Vagrant のインストールを検討
  - VBoxManage のラッパースクリプトで LD_LIBRARY_PATH を浄化する案
- [ ] コンテナの単体テスト・結合テストを iMac 環境で実施
- [ ] Vagrantfile を M2 Mac / iMac 両環境で使い分け可能にする

---

## 学び

- `NS_ERROR_INVALID_ARG` は一見引数エラーだが、**ディスク容量不足**が原因の場合がある
- VBox ログにエラーがなく VM が poweroff になる場合、**ホスト側の問題**（OOM、ライブラリ競合）を疑う
- Vagrant AppImage がバンドルするライブラリは VirtualBox と干渉する場合がある
- `VBoxManage startvm` で手動起動すればライブラリ汚染を回避できる
- `/sgoinfre` は 42 環境で永続的な大容量ストレージとして VM 置き場に適している
- ディレクトリ名のスペースは避けた方がトラブルが少ない（`VirtualBox_VMs`）

---

## 次のセッションでやること

**既存コンテナ（MariaDB, NGINX）の iMac 環境での動作確認**

- 環境: 校舎 旧PC（iMac + Ubuntu）
- フェーズ3（WordPress）は 3-1 精読の途中、次セッションではコンテナテストを優先
- 残り時間: 約50時間

### VM 起動手順（iMac ワークアラウンド）

`vagrant up` は Vagrant AppImage のライブラリ汚染で poweroff になるため、手動で補完する。

```bash
# 1. VM起動（既存VMがある場合）
VM_NAME=$(VBoxManage list vms | head -1 | sed 's/"\(.*\)".*/\1/')
VBoxManage startvm "$VM_NAME" --type headless
sleep 15
ssh -p 2222 vagrant@127.0.0.1   # パスワード: vagrant

# 2. ゲスト内セットアップ（起動ごとに必要）
sudo modprobe vboxsf
sudo mkdir -p /vagrant
sudo mount -t vboxsf vagrant /vagrant

# 3. VMが存在しない場合（初回のみ）
# → セッション#0015 の「ワークアラウンド手順」を参照
```

### iMac 環境の現在の状態

| 項目 | 値 |
|------|-----|
| VM名 | `vm_default_1775761662708_15919` |
| VM保存先 | `/sgoinfre/torinoue/VirtualBox_VMs` |
| VirtualBox machinefolder | `/sgoinfre/torinoue/VirtualBox_VMs` に変更済み |
| 共有フォルダ | `/home/torinoue/0409inception` → `/vagrant` |
| Docker | 29.4.0 / Compose v5.1.2 |
| SSH | `ssh -p 2222 vagrant@127.0.0.1` (pw: vagrant) |

### 注意事項

- ゾンビ VBoxHeadless プロセスの確認を習慣づける: `ps aux | grep VBoxHeadless`
- `/sgoinfre` は共有ストレージなので席を変えても VM は残る
- `vagrant up` 一発起動の根本修正は残課題（締切までの時間次第で対応判断）

---

## 未解決事項

- Vagrant AppImage ライブラリ汚染の根本修正（`vagrant up` 一発起動）
- phase_plan.md の開発環境欄の更新（iMac 追加、Dell 削除）

---

## 新しいチャット開始時のコピペ用指示文

```
Inception課題（42Tokyo）を進めています。
以下を読んで現在地を把握してから作業を始めてください:
- dev_docs/phase_plan.md（全体計画・運用ルール）
- session_logs/0015_session_log_inception.md（最新セッションログ）

今日やること: 既存コンテナ（MariaDB, NGINX）の iMac 環境での動作確認
環境: 校舎 旧PC（iMac + Ubuntu + VirtualBox）
残り時間: 約50時間

注意: iMac 環境では vagrant up が動かないため手動ワークアラウンドが必要。
詳細はセッションログ#0015 の「ワークアラウンド手順」を参照。

セッション開始時刻の記録（ターミナルで実行し、結果をチャットに貼る）:
date '+%Y-%m-%d %H:%M'
```
