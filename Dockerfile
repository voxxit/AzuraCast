#
# Base install step (done first for caching purposes).
#
FROM ubuntu:focal as base

ARG TARGETARCH
ARG TARGETOS

ENV TZ="UTC"

# Run base build process
COPY ./util/docker/web/ /bd_build

RUN chmod a+x /bd_build/*.sh \
    && /bd_build/prepare.sh \
    && /bd_build/add_user.sh \
    && /bd_build/setup.sh \
    && /bd_build/cleanup.sh \
    && rm -rf /bd_build

# Install SFTPgo
ENV SFTPGO_VERSION v1.2.2

RUN apt-get update \
   && apt-get -y install xz-utils \
   && case "${TARGETARCH}" in \
      arm64) \
         packageArch=linux_arm64 \
         ;; \
      amd64) \
         packageArch=linux_x86_64 \
         ;; \
      *) \
         echo "sftpgo: Target architecture not supported; aborting build..." && exit 1 \
         ;; \
   esac \
   \
   && mkdir -p /sftpgo/src \
   && cd /sftpgo/src \
   && wget https://github.com/drakkan/sftpgo/releases/download/${SFTPGO_VERSION}/sftpgo_${SFTPGO_VERSION}_${packageArch}.tar.xz \
   && tar -xf sftpgo_${SFTPGO_VERSION}_${packageArch}.tar.xz \
   && mv ./sftpgo /usr/local/bin/ \
   && rm -rf /sftpgo \
   && apt-get purge -y --auto-remove xz-utils \
   && rm -rf /var/lib/apt/lists/*

# Install Dockerize
ENV DOCKERIZE_VERSION v0.7.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget ca-certificates openssl \
    && wget https://github.com/voxxit/dockerize/releases/download/${DOCKERIZE_VERSION}/dockerize-${TARGETOS}-${TARGETARCH}-${DOCKERIZE_VERSION}.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-${TARGETOS}-${TARGETARCH}-${DOCKERIZE_VERSION}.tar.gz \
    && rm dockerize-${TARGETOS}-${TARGETARCH}-${DOCKERIZE_VERSION}.tar.gz

#
# START Operations as `azuracast` user
#
USER azuracast

WORKDIR /var/azuracast/www

COPY --chown=azuracast:azuracast ./composer.json ./composer.lock ./
RUN composer install \
    --no-dev \
    --no-ansi \
    --no-autoloader \
    --no-interaction

COPY --chown=azuracast:azuracast . .

RUN composer dump-autoload --optimize --classmap-authoritative \
    && touch /var/azuracast/.docker

VOLUME ["/var/azuracast/www_tmp", "/var/azuracast/backups", "/etc/letsencrypt", "/var/azuracast/sftpgo/persist"]

#
# END Operations as `azuracast` user
#
USER root

EXPOSE 80 2022

# Nginx Proxy environment variables.
ENV VIRTUAL_HOST="azuracast.local" \
    HTTPS_METHOD="noredirect"

# Sensible default environment variables.
ENV APPLICATION_ENV="production" \
    ENABLE_ADVANCED_FEATURES="false" \
    MYSQL_HOST="mariadb" \
    MYSQL_PORT=3306 \
    MYSQL_USER="azuracast" \
    MYSQL_PASSWORD="azur4c457" \
    MYSQL_DATABASE="azuracast" \
    PREFER_RELEASE_BUILDS="false" \
    COMPOSER_PLUGIN_MODE="false" \
    ADDITIONAL_MEDIA_SYNC_WORKER_COUNT=0

# Entrypoint and default command
ENTRYPOINT ["/usr/local/bin/uptime_wait"]
CMD ["/usr/local/bin/my_init"]
