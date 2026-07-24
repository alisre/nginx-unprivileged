ARG IMAGE=alpine:3.24
FROM $IMAGE

LABEL maintainer="idouying"

ENV NGINX_VERSION=1.30.4

ARG UID=1001
ARG GID=1001

# Build nginx from source with all required modules
RUN set -x \
    && addgroup -g $GID -S nginx || true \
    && adduser -S -D -H -u $UID -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx || true \
# install build dependencies
    && apk add --no-cache --virtual .build-deps \
        gcc \
        libc-dev \
        make \
        openssl-dev \
        pcre2-dev \
        zlib-dev \
        linux-headers \
        curl \
    && mkdir -p /usr/src \
    && curl -fSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o /usr/src/nginx.tar.gz \
    && tar -xzf /usr/src/nginx.tar.gz -C /usr/src \
    && cd /usr/src/nginx-${NGINX_VERSION} \
    && ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/tmp/nginx.pid \
        --lock-path=/tmp/nginx.lock \
        --http-client-body-temp-path=/tmp/client_temp \
        --http-proxy-temp-path=/tmp/proxy_temp \
        --http-fastcgi-temp-path=/tmp/fastcgi_temp \
        --http-uwsgi-temp-path=/tmp/uwsgi_temp \
        --http-scgi-temp-path=/tmp/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-compat \
        --with-file-aio \
        --with-threads \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_realip_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_v2_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-stream_realip_module \
    && make -j$(nproc) \
    && make install \
    && cd / \
    && rm -rf /usr/src/nginx.tar.gz /usr/src/nginx-${NGINX_VERSION} \
# strip binary
    && strip /usr/sbin/nginx \
# remove build deps, keep runtime deps
    && apk del --no-network .build-deps \
    && apk add --no-cache \
        pcre2 \
        openssl \
        zlib \
# Add envsubst for templating environment variables
        gettext-envsubst \
# Bring in tzdata so users could set the timezones through the environment variables
        tzdata \
# Add curl for healthcheck
        curl \
        ca-certificates \
# create required directories
    && mkdir -p /var/cache/nginx \
    && mkdir -p /var/log/nginx \
    && mkdir -p /etc/nginx/conf.d \
    && mkdir -p /usr/share/nginx/html \
# forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
# create a docker-entrypoint.d directory
    && mkdir /docker-entrypoint.d

# Patch default nginx.conf for unprivileged use and stream support
RUN sed -i 's/listen       80;/listen       8080;/' /etc/nginx/nginx.conf \
    && sed -i '/user  nobody;/d' /etc/nginx/nginx.conf \
    && mkdir -p /etc/nginx/conf.d \
# Create default.conf with port 8080
    && printf 'server {\n    listen       8080;\n    server_name  localhost;\n    location / {\n        root   /etc/nginx/html;\n        index  index.html index.htm;\n    }\n    error_page   500 502 503 504  /50x.html;\n    location = /50x.html {\n        root   /etc/nginx/html;\n    }\n}\n' > /etc/nginx/conf.d/default.conf \
# Add stream and conf.d includes to nginx.conf
    && sed -i '/^http {/i stream {\n    include /etc/nginx/conf.d/*.stream;\n}' /etc/nginx/nginx.conf \
    && sed -i '/^http {/a \    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf \
# set permissions for non-root user
    && chown -R $UID:0 /var/cache/nginx \
    && chmod -R g+w /var/cache/nginx \
    && chown -R $UID:0 /etc/nginx \
    && chmod -R g+w /etc/nginx

COPY docker-entrypoint.sh /
COPY 10-listen-on-ipv6-by-default.sh /docker-entrypoint.d
COPY 20-envsubst-on-templates.sh /docker-entrypoint.d
COPY 30-tune-worker-processes.sh /docker-entrypoint.d

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -fsk https://localhost:443/ || curl -fs http://localhost:8080/ || exit 1

STOPSIGNAL SIGQUIT

USER $UID

CMD ["nginx", "-g", "daemon off;"]
