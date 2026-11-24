#!/usr/bin/env bash
# Quit Companion - one-time setup of a fresh Ubuntu 24.04 or 26.04 LTS EC2 server.
# Run as the default "ubuntu" user (it uses sudo). Safe to re-run.
# deploy/aws/deploy.sh uploads and runs it automatically when Docker is missing.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "== swap (2 GB headroom for image builds on a small server)"
if ! sudo swapon --show=NAME --noheadings | grep -qx /swapfile; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile >/dev/null
  sudo swapon /swapfile
fi
grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
free -m | awk 'NR<=3'

echo "== Docker Engine + Compose plugin (Docker's official apt repository)"
if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update -q
  sudo apt-get install -y -q ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -q
  sudo apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
sudo systemctl enable --now docker >/dev/null 2>&1
# Lets later SSH sessions run docker without sudo (takes effect on next login).
sudo usermod -aG docker "$USER"

echo "== app folders"
# secrets/: the Firebase Admin key, readable only by the container user.
install -d -m 700 "$HOME/quit-companion/secrets" "$HOME/quit-companion/.incoming"
install -d -m 755 "$HOME/quit-companion/app" "$HOME/quit-companion/releases"

sudo docker --version
sudo docker compose version
echo "server user: $(id -un) uid=$(id -u)"
echo "BOOTSTRAP OK"
