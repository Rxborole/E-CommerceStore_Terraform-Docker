
#!/usr/bin/env bash
# Build and push all five application images for AWS EC2 (AMD64).
# Usage: DOCKERHUB_USER=rxborole ./scripts/build_and_push.sh [tag]

set -euo pipefail

: "${DOCKERHUB_USER:?Set DOCKERHUB_USER to your Docker Hub username}"

TAG="${1:-v1}"
PLATFORM="linux/amd64"

cd "$(dirname "$0")/.."

# Authenticate once with Docker Hub.
docker login
docker buildx inspect --bootstrap

# Build and push the four backend services.
for svc in user-service product-service cart-service order-service; do
  echo ">>> Building $svc for $PLATFORM"

  docker buildx build \
    --platform "$PLATFORM" \
    --tag "$DOCKERHUB_USER/ecommerce-$svc:$TAG" \
    --push \
    "backend/$svc"
done

# Build and push the frontend.
echo ">>> Building frontend for $PLATFORM"

docker buildx build \
  --platform "$PLATFORM" \
  --tag "$DOCKERHUB_USER/ecommerce-frontend:$TAG" \
  --push \
  frontend

echo "Done. All five $PLATFORM images pushed with tag '$TAG'."
