# VM 内 Docker 環境セットアップマニュアル

> 作成日: 2026-04-17
> 対象 VM: Ubuntu 22.04.5 LTS (0417Inception_vm)
> 前提: VM に SSH 接続済み、共有フォルダ `/media/sf_inception` がマウント済み

## 1. Docker のインストール

### 1-1. 前提パッケージのインストール

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl -y
```

### 1-2. Docker 公式 GPG キーの設定

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

### 1-3. Docker リポジトリの追加

```bash
echo "Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc" | sudo tee /etc/apt/sources.list.d/docker.sources
```

### 1-4. Docker のインストール

```bash
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin make -y
```

### 1-5. ユーザーを docker グループに追加

```bash
sudo usermod -aG docker torinoue
```

反映にはログアウト→再ログインが必要:

```bash
exit
ssh -p 3322 torinoue@localhost
```

### 1-6. 動作確認

```bash
docker --version
docker compose version
docker run --rm hello-world
```

期待される出力例:

```
Docker version 29.4.0, build 9d7ad9f
Docker Compose version v5.1.3
Hello from Docker!
```

## 2. Inception 課題用の追加設定

### 2-1. /etc/hosts の設定

```bash
sudo sh -c "echo '127.0.0.1 torinoue.42.fr' >> /etc/hosts"
```

確認:

```bash
cat /etc/hosts | grep torinoue
```

期待される出力:

```
127.0.0.1 torinoue.42.fr
```

### 2-2. データディレクトリの作成

Docker ボリュームのバインドマウント先:

```bash
sudo mkdir -p /home/torinoue/data/mariadb /home/torinoue/data/wordpress
```

確認:

```bash
ls -la /home/torinoue/data/
```

## 3. 共有フォルダからのプロジェクト利用

共有フォルダのパス:

```
/media/sf_inception/srcs/docker-compose.yml
/media/sf_inception/srcs/requirements/       (各コンテナの Dockerfile 等)
/media/sf_inception/srcs/.env                (環境変数)
/media/sf_inception/secrets/                 (Docker secrets)
```

### docker compose の実行

```bash
cd /media/sf_inception/srcs
docker compose up --build
```

## 4. セットアップ状態の確認チェックリスト

| # | 確認項目 | コマンド | 期待値 |
|---|---------|---------|--------|
| 1 | Docker バージョン | `docker --version` | 29.x.x |
| 2 | Compose バージョン | `docker compose version` | v5.x.x |
| 3 | sudo なしで docker | `docker run --rm hello-world` | エラーなし |
| 4 | hosts 設定 | `cat /etc/hosts \| grep torinoue` | `127.0.0.1 torinoue.42.fr` |
| 5 | データディレクトリ | `ls /home/torinoue/data/` | `mariadb wordpress` |
| 6 | 共有フォルダ | `ls /media/sf_inception/srcs/` | `docker-compose.yml requirements ...` |

## 注意事項

- 共有フォルダ（vboxsf）上での Docker ビルドは、ネイティブファイルシステムより遅くなる場合がある
- パフォーマンスに問題がある場合は、ソースを VM 内にコピーしてビルドすることを検討:

```bash
cp -r /media/sf_inception/ ~/inception_local/
cd ~/inception_local/srcs
docker compose up --build
```

- VM の再起動後は共有フォルダが自動マウントされる（`--automount` 設定済み）
- VM の再起動後も Docker は自動起動する（systemd で有効化済み）
