# VirtualBox VM 作成・SSH 接続マニュアル（校舎環境 / Vagrant 不使用）

> 作成日: 2026-04-17
> 環境: 42Tokyo 校舎 Dell (Intel Core i7-14700) / VirtualBox 7.0.26 / Ubuntu 22.04 ホスト
> 制約: ホスト側に sudo 権限なし。ストレージは `goinfre` または `sgoinfre` を使用

## 前提条件

- VirtualBox 7.0.26 がホストにインストール済み
- `VBoxManage` コマンドがユーザー権限で利用可能
- Ubuntu 22.04 Server の ISO、または既存の VDI が利用可能
- ストレージパス例: `~/goinfre/VirtualBox_VMs/`

## 1. VirtualBox のデフォルトパスを確認・変更

```bash
VBoxManage list systemproperties | grep "Default machine folder"
```

goinfre 等に変更する場合:

```bash
VBoxManage setproperty machinefolder ~/goinfre/VirtualBox_VMs
```

## 2. VM の作成（既存 VM がない場合）

```bash
VBoxManage createvm --name "0417Inception_vm" --ostype Ubuntu_64 --register
```

### メモリ・CPU の設定

```bash
VBoxManage modifyvm "0417Inception_vm" --memory 2048 --cpus 2
```

### 仮想ディスクの作成・接続

```bash
VBoxManage createmedium disk --filename ~/goinfre/VirtualBox_VMs/0417Inception_vm/disk.vdi --size 20480

VBoxManage storagectl "0417Inception_vm" --name "SATA" --add sata --controller IntelAhci

VBoxManage storageattach "0417Inception_vm" --storagectl "SATA" --port 0 --device 0 --type hdd --medium ~/goinfre/VirtualBox_VMs/0417Inception_vm/disk.vdi
```

### ISO からのインストール（必要な場合）

```bash
VBoxManage storagectl "0417Inception_vm" --name "IDE" --add ide

VBoxManage storageattach "0417Inception_vm" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium /path/to/ubuntu-22.04-live-server-amd64.iso
```

### 14世代 CPU 向けの安定化設定

```bash
VBoxManage modifyvm "0417Inception_vm" --paravirt-provider kvm
VBoxManage modifyvm "0417Inception_vm" --hwvirtex on
VBoxManage modifyvm "0417Inception_vm" --vtxvpid on
VBoxManage modifyvm "0417Inception_vm" --vtxux on
VBoxManage modifyvm "0417Inception_vm" --audio none
VBoxManage modifyvm "0417Inception_vm" --graphicscontroller vmsvga
```

## 3. ネットワーク設定（NAT + ポートフォワーディング）

SSH 用のポートフォワーディングを設定する（ホスト 3322 → ゲスト 22）:

```bash
VBoxManage modifyvm "0417Inception_vm" --natpf1 "ssh,tcp,,3322,,22"
```

HTTPS 用のポートフォワーディング（ホスト 54321 → ゲスト 443）:

```bash
VBoxManage modifyvm "0417Inception_vm" --natpf1 "https,tcp,,54321,,443"
```

### ポートフォワーディングの確認

```bash
VBoxManage showvminfo "0417Inception_vm" | grep -i "nic\|rule\|forward"
```

### VM 起動中にルールを変更する場合

```bash
VBoxManage controlvm "0417Inception_vm" natpf1 delete ssh
VBoxManage controlvm "0417Inception_vm" natpf1 "ssh,tcp,,3322,,22"
```

## 4. 共有フォルダの設定

**VM を停止した状態で** 実行する:

```bash
VBoxManage sharedfolder add "0417Inception_vm" --name "inception" --hostpath "/home/torinoue/torinoue_inception" --automount
```

> VM 起動中に `sharedfolder add` を実行すると `VBOX_E_INVALID_OBJECT_STATE` エラーになる。
> VirtualBox 7.0.26 の `controlvm` には `sharedfolder` サブコマンドが存在しない。

### ゲスト側でのアクセス許可

VM 内で `torinoue` ユーザーを `vboxsf` グループに追加:

```bash
sudo usermod -aG vboxsf torinoue
```

反映にはログアウト→再ログインが必要。

### マウントポイント

`--automount` 指定時は Guest Additions が自動で `/media/sf_inception` にマウントする。

手動マウントの場合:

```bash
sudo mkdir -p /vagrant
sudo mount -t vboxsf inception /vagrant
```

## 5. VM の起動・停止・SSH 接続

### ヘッドレス起動

```bash
VBoxManage startvm "0417Inception_vm" --type headless
```

### SSH 接続

```bash
ssh -p 3322 torinoue@localhost
```

### VM の停止

```bash
VBoxManage controlvm "0417Inception_vm" poweroff
```

### 状態確認

```bash
VBoxManage list runningvms
ss -tlnp | grep 3322
```

## トラブルシューティング

### SSH 接続できない場合

1. VM が起動しているか確認: `VBoxManage list runningvms`
2. ポートフォワーディングが設定されているか確認: `VBoxManage showvminfo "0417Inception_vm" | grep Rule`
3. ポートが LISTEN しているか確認: `ss -tlnp | grep 3322`
4. 古い SSH セッションが残っている場合: `lsof -i :3322` で確認し、`kill <PID>` で切断

### 共有フォルダに Permission denied

`vboxsf` グループに追加されているか確認:

```bash
groups torinoue
```

### known_hosts の警告が出る場合

VM を再作成すると SSH ホスト鍵が変わるため:

```bash
ssh-keygen -R "[localhost]:3322"
```
