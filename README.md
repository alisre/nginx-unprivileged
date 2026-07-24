# nginx-unprivileged

基于 Alpine 的非 root nginx 镜像，nginx 进程以 UID 1001 运行。

## 构建

```bash
# 默认构建
bash build.sh

# 自定义镜像名和标签
IMAGE_NAME=my-nginx IMAGE_TAG=1.30.4 bash build.sh

# 或直接 docker build
docker build --build-arg UID=1001 --build-arg GID=1001 -t nginx-unprivileged .
```

## 运行

```bash
docker run -d -p 8080:8080 nginx-unprivileged
```

## 关键特性

- **非 root 运行**：nginx 以 UID=1001 / GID=1001 运行
- **监听 8080 端口**（非特权端口）
- **Alpine 基础镜像**：体积小
- **支持环境变量模板**：将 `.template` 文件放入 `/etc/nginx/templates/`，启动时自动 envsubst
- **自动 worker_processes 调优**：设置 `NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE=1` 启用

## 自定义配置

挂载自定义 nginx 配置：

```bash
docker run -d -p 8080:8080 \
  -v ./nginx.conf:/etc/nginx/nginx.conf:ro \
  -v ./conf.d:/etc/nginx/conf.d:ro \
  nginx-unprivileged
```

使用模板（支持环境变量替换）：

```bash
docker run -d -p 8080:8080 \
  -v ./templates:/etc/nginx/templates:ro \
  -e MY_VAR=value \
  nginx-unprivileged
```

## 更新 nginx 版本

修改 Dockerfile 中的 `NGINX_VERSION` 和 `PKG_RELEASE` 即可。
