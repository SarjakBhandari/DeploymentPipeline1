#!/bin/bash

set -e
echo " Removing pre-existing Docker packages..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  sudo apt-get remove -y $pkg || true
done

echo "Adding Docker's official GPG key..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "Adding Docker repository to APT sources..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "🚀 Installing Docker and Compose..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose

echo "Starting local Docker registry on port 5000 with persistent volume..."
sudo mkdir -p /opt/registry/data

if [ "$(docker ps -a --filter name=registry --format '{{.Names}}')" = "registry" ]; then
  echo "🛑 Registry container already exists. Skipping creation."
else
  docker run -d \
    --restart=always \
    --name registry \
    -p 5000:5000 \
    -v /opt/registry/data:/var/lib/registry \
    registry:2
  echo "✅ Registry container started."
sudo apt upgrade -y
sudo apt install openjdk-21-jdk -y
fi





