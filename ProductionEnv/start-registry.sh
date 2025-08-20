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
fi


echo "Validating vm.max_map_count for SonarQube..."
current_vm_map=$(sysctl -n vm.max_map_count)
if [ "$current_vm_map" -lt 262144 ]; then
  echo "Increasing vm.max_map_count to 262144..."
  sudo sysctl -w vm.max_map_count=262144
  echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
fi

echo "Setting up SonarQube stack..."
mkdir -p ~/sonarcube
cd ~/sonarcube

cat <<EOF > docker-compose.yml
version: '3.2'

services:
  sonarqube:
    image: sonarqube:9.9.3-community
    container_name: sonarqube
    ports:
      - "9000:9000"
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    depends_on:
      - db
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_logs:/opt/sonarqube/logs
      - sonarqube_extensions:/opt/sonarqube/extensions
    restart: always

  db:
    image: postgres:13
    container_name: sonar_db
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: always

volumes:
  sonarqube_data:
  sonarqube_logs:
  sonarqube_extensions:
  postgres_data:
EOF

echo "Launching SonarQube and PostgreSQL containers..."
docker-compose down -v
docker-compose pull
docker-compose up -d --force-recreate


echo "SonarQube stack launched. Waiting for readiness..."
sleep 10
docker logs sonarqube | grep -q "SonarQube is operational" && echo " SonarQube is ready!" || echo "Still initializing..."