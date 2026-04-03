#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin git curl
sudo systemctl enable docker
sudo systemctl start docker

if ! groups "$USER" | grep -q docker; then
  sudo usermod -aG docker "$USER"
  echo "Added $USER to docker group. Log out and back in before running deploy script."
fi

echo "Oracle VM base setup complete."
