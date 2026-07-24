#!/bin/bash
# 检查 nginx stable 最新版本和可用的 Alpine 版本
set -euo pipefail

echo "=== 检查 nginx stable 最新版本 ==="
echo "当前 Dockerfile 配置:"
grep -E "^ARG (NGINX_VERSION|PKG_RELEASE|ALPINE_VERSION)" Dockerfile

echo ""
echo "nginx 官方 Alpine 仓库可用版本:"
ALPINE_VER="${1:-3.24}"
URL="https://nginx.org/packages/alpine/v${ALPINE_VER}/main/x86_64/"
echo "  仓库: $URL"
wget -qO- "$URL" 2>/dev/null | grep -oP 'nginx-\K[0-9]+\.[0-9]+\.[0-9]+-r[0-9]+' | sort -V | tail -5 | while read -r ver; do
  echo "  可用: nginx=$ver"
done || echo "  (需要网络访问，或安装 wget)"

echo ""
echo "=== 升级步骤 ==="
echo "1. 修改 Dockerfile 中 NGINX_VERSION 和 PKG_RELEASE"
echo "2. 如升级 Alpine，修改 ALPINE_VERSION"
echo "3. 运行: bash build.sh"
echo "4. 验证: docker run --rm nginx-unprivileged nginx -v"
