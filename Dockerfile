ARG ALPINE_VERSION=3.24
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="idouying"

# Pin nginx version for reproducible builds
ARG NGINX_VERSION=1.30.4
ARG PKG_RELEASE=1

# nginx user/group ID
ARG UID=1001
ARG GID=1001

ENV NGINX_VERSION=${NGINX_VERSION}
ENV PKG_RELEASE=${PKG_RELEASE}

RUN set -x \
    && addgroup -g $GID -S nginx \
    && adduser -S -D -H -u $UID -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
    && apkArch="$(cat /etc/apk/arch)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-r${PKG_RELEASE} \
    " \
    && case "$apkArch" in \
        x86_64|aarch64) \
            set -x \
            && KEY_SHA512="e09fa32f0a0eab2b879ccbbc4d0e4fb9751486eedda75e35fac65802cc9faa266425edf83e261137a2f4d16281ce2c1a5f4502930fe75154723da014214f0655" \
            && wget -O /tmp/nginx_signing.rsa.pub https://nginx.org/keys/nginx_signing.rsa.pub \
            && if echo "$KEY_SHA512 */tmp/nginx_signing.rsa.pub" | sha512sum -c -; then \
                echo "key verification succeeded!"; \
                mv /tmp/nginx_signing.rsa.pub /etc/apk/keys/; \
            else \
                echo "key verification failed!"; \
                exit 1; \
            fi \
            && apk add -X "https://nginx.org/packages/alpine/v$(egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release)/main" --no-cache $nginxPackages \
            ;; \
        *) \
            echo "Unsupported architecture: $apkArch"; \
            exit 1; \
            ;; \
    esac \
    && if [ -f "/etc/apk/keys/nginx_signing.rsa.pub" ]; then rm -f /etc/apk/keys/nginx_signing.rsa.pub; fi \
    && apk add --no-cache gettext-envsubst \
    && apk add --no-cache tzdata \
    && apk add --no-cache curl ca-certificates \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && mkdir /docker-entrypoint.d

# Configure nginx to run as unprivileged user on port 8080
RUN mkdir -p /etc/nginx/conf.d \
    && if [ -f /etc/nginx/conf.d/default.conf ]; then \
        sed -i 's,listen       80;,listen       8080;,' /etc/nginx/conf.d/default.conf; \
    else \
        printf '%s\n' \
            'server {' \
            '    listen       8080;' \
            '    server_name  localhost;' \
            '    location / {' \
            '        root   /usr/share/nginx/html;' \
            '        index  index.html index.htm;' \
            '    }' \
            '    error_page   500 502 503 504  /50x.html;' \
            '    location = /50x.html {' \
            '        root   /usr/share/nginx/html;' \
            '    }' \
            '}' > /etc/nginx/conf.d/default.conf; \
    fi \
    && sed -i '/user  nginx;/d' /etc/nginx/nginx.conf \
    && sed -i 's,/run/nginx.pid,/tmp/nginx.pid,' /etc/nginx/nginx.conf \
    && printf '%s\n' \
        '    proxy_temp_path /tmp/proxy_temp;' \
        '    client_body_temp_path /tmp/client_temp;' \
        '    fastcgi_temp_path /tmp/fastcgi_temp;' \
        '    uwsgi_temp_path /tmp/uwsgi_temp;' \
        '    scgi_temp_path /tmp/scgi_temp;' \
        > /tmp/nginx_temp_paths.conf \
    && sed -i '/^http {/r /tmp/nginx_temp_paths.conf' /etc/nginx/nginx.conf \
    && rm -f /tmp/nginx_temp_paths.conf \
    && chown -R $UID:0 /var/cache/nginx \
    && chmod -R g+w /var/cache/nginx \
    && chown -R $UID:0 /etc/nginx \
    && chmod -R g+w /etc/nginx

COPY docker-entrypoint.sh /
COPY 10-listen-on-ipv6-by-default.sh /docker-entrypoint.d/
COPY 20-envsubst-on-templates.sh /docker-entrypoint.d/
COPY 30-tune-worker-processes.sh /docker-entrypoint.d/

# Remove unnecessary packages after setup to reduce attack surface
RUN apk del --no-cache wget && rm -rf /var/cache/apk/*

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -fsk https://localhost:443/ || curl -fs http://localhost:8080/ || exit 1

STOPSIGNAL SIGQUIT

USER $UID

CMD ["nginx", "-g", "daemon off;"]
