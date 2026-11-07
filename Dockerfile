ARG ALPINE_VERSION="3.24"

FROM docker.io/library/alpine:${ALPINE_VERSION}
LABEL maintainer="andreub (fork of github.com/tiredofit/docker-traefik-cloudflare-companion)" \
      org.opencontainers.image.source="https://github.com/andreub/docker-traefik-cloudflare-companion"

ENV IMAGE_NAME="andreub/docker-traefik-cloudflare-companion" \
    IMAGE_REPO_URL="https://github.com/andreub/docker-traefik-cloudflare-companion/"

COPY requirements.txt /tmp/requirements.txt

RUN set -eux && \
    addgroup -S -g 8080 tcc && \
    adduser -D -S -s /sbin/nologin \
            -h /dev/null \
            -G tcc \
            -g "tcc" \
            -u 8080 tcc \
            && \
    \
    apk upgrade --no-cache && \
    apk add --no-cache --virtual .tcc-build-deps \
                cargo \
                gcc \
                libffi-dev \
                musl-dev \
                openssl-dev \
                py3-pip \
                py3-setuptools \
                py3-wheel \
                python3-dev \
                && \
    \
    apk add --no-cache \
                ca-certificates \
                py3-beautifulsoup4 \
                py3-certifi \
                py3-chardet \
                py3-docker-py \
                py3-idna \
                py3-openssl \
                py3-packaging \
                py3-requests \
                py3-soupsieve \
                py3-urllib3 \
                py3-websocket-client \
                py3-yaml \
                python3 \
                su-exec \
                tini \
                tzdata \
                && \
    \
    pip install --no-cache-dir --break-system-packages -r /tmp/requirements.txt && \
    \
    apk del .tcc-build-deps && \
    rm -rf /root/.cache \
           /root/.cargo \
           /tmp/requirements.txt

COPY install /

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/docker-entrypoint"]
