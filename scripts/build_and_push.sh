#!/usr/bin/env bash
# Build, tag and push all 5 images to Docker Hub.
# Usage: DOCKERHUB_USER=yourname ./scripts/build_and_push.sh [tag]
set -euo pipefail
: "${DOCKERHUB_USER:?Set DOCKERHUB_USER to your Docker Hub username}"
TAG="${1:-v1}"
cd "$(dirname "$0")/.."

docker login   # prompts for your Docker Hub credentials

for svc in user-service product-service cart-service order-service; do
  echo ">>> Building $svc"
  docker build -t "$DOCKERHUB_USER/ecommerce-$svc:$TAG" "backend/$svc"
  docker push "$DOCKERHUB_USER/ecommerce-$svc:$TAG"
done

echo ">>> Building frontend"
docker build -t "$DOCKERHUB_USER/ecommerce-frontend:$TAG" frontend
docker push "$DOCKERHUB_USER/ecommerce-frontend:$TAG"

echo "Done. Images pushed with tag '$TAG'. Make sure the repos are PUBLIC on Docker Hub."
