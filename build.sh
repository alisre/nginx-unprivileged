#!/bin/bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-nginx-unprivileged}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

docker build \
  --build-arg UID=1001 \
  --build-arg GID=1001 \
  -t "${IMAGE_NAME}:${IMAGE_TAG}" \
  .

echo "Built: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  nginx UID/GID: 1001"
echo "  Listening on port: 8080"
echo ""
echo "Run:"
echo "  docker run -d -p 8080:8080 ${IMAGE_NAME}:${IMAGE_TAG}"
