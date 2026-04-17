#!/bin/bash
sudo apt-get update

sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<DOCKER
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
DOCKER

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo apt-get install make -y
sudo usermod -aG docker vagrant

sudo -- sh -c "echo '127.0.0.1 toruinoue.42.fr' >> /etc/hosts"
sudo mkdir -p /home/torinoue/data/mariadb /home/torinoue/data/wordpress
sudo chown -R torinoue:torinoue /home/torinoue/data