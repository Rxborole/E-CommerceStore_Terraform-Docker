#!/bin/bash
# Runs once as root on first boot. Log: /var/log/user-data.log
set -euo pipefail
exec > /var/log/user-data.log 2>&1
export DEBIAN_FRONTEND=noninteractive

HUB="${dockerhub_username}"
TAG="${image_tag}"
NET="ecommerce-net"

retry() { for i in 1 2 3 4 5; do "$@" && return 0; echo "retry $i: $*"; sleep 10; done; return 1; }

echo "[1/5] Installing Docker"
retry apt-get update -y
retry apt-get install -y docker.io curl
systemctl enable --now docker
usermod -aG docker ubuntu || true

echo "[2/5] Creating Docker network"
docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET"

echo "[3/5] Pulling images from Docker Hub"
retry docker pull mongo:6.0
for svc in user-service product-service cart-service order-service frontend; do
  retry docker pull "$HUB/ecommerce-$svc:$TAG"
done

echo "[4/5] Starting containers"
docker run -d --name mongo --network "$NET" --restart unless-stopped \
  -v mongo-data:/data/db mongo:6.0

docker run -d --name user-service --network "$NET" --restart unless-stopped \
  -p 3001:3001 -e PORT=3001 \
  -e MONGODB_URI=mongodb://mongo:27017/ecommerce_users \
  -e JWT_SECRET="${jwt_secret}" \
  "$HUB/ecommerce-user-service:$TAG"

docker run -d --name product-service --network "$NET" --restart unless-stopped \
  -p 3002:3002 -e PORT=3002 \
  -e MONGODB_URI=mongodb://mongo:27017/ecommerce_products \
  "$HUB/ecommerce-product-service:$TAG"

docker run -d --name cart-service --network "$NET" --restart unless-stopped \
  -p 3003:3003 -e PORT=3003 \
  -e MONGODB_URI=mongodb://mongo:27017/ecommerce_carts \
  -e PRODUCT_SERVICE_URL=http://product-service:3002 \
  "$HUB/ecommerce-cart-service:$TAG"

docker run -d --name order-service --network "$NET" --restart unless-stopped \
  -p 3004:3004 -e PORT=3004 \
  -e MONGODB_URI=mongodb://mongo:27017/ecommerce_orders \
  -e CART_SERVICE_URL=http://cart-service:3003 \
  -e PRODUCT_SERVICE_URL=http://product-service:3002 \
  -e USER_SERVICE_URL=http://user-service:3001 \
  "$HUB/ecommerce-order-service:$TAG"

# Frontend last: nginx resolves backend container names on startup
docker run -d --name frontend --network "$NET" --restart unless-stopped \
  -p 80:80 "$HUB/ecommerce-frontend:$TAG"

echo "[5/5] Verifying"
sleep 15
for port in 3001 3002 3003 3004; do
  curl -fsS "http://localhost:$port/" && echo " <- port $port OK" || echo "port $port FAILED"
done
curl -fsS http://localhost/live || echo "frontend FAILED"
docker ps
echo "Deployment finished."
