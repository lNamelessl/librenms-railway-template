# LibreNMS Railway template image — thin wrapper around the pinned official image.
#
# Why a wrapper? Railway enforces one volume per service, so the upstream
# dispatcher SIDECAR (which shares /data) cannot be deployed there. This
# image consolidates the upstream compose topology into a single container:
#   - SIDECAR_DISPATCHER=1 starts librenms-service.py (the poller/discovery
#     dispatcher — the same continuous poller the upstream compose runs as a
#     sidecar) while adapted 04-svc-main.sh + 07-svc-cron.sh keep the web UI
#     (nginx/php-fpm), snmpd and cron alive in the same container — upstream
#     would strip them for sidecar roles
#   - a first-boot seed sets icmp_check=false: Railway containers run
#     without CAP_NET_RAW, so fping can never work; without this, SNMP
#     devices are marked down before SNMP is ever tried
#   - the ENV block bakes the template's default configuration so the
#     marketplace deploy needs zero manual inputs; per-deploy secrets and
#     hostnames stay as Railway expression variables (see README)
FROM librenms/librenms:26.8.2

ENV SIDECAR_DISPATCHER=1 \
    DISPATCHER_NODE_ID=railway-main \
    DB_NAME=librenms \
    DB_USER=librenms \
    DB_PORT=3306 \
    DB_TIMEOUT=120 \
    REDIS_PORT=6379 \
    CACHE_DRIVER=redis \
    SESSION_DRIVER=redis \
    MEMORY_LIMIT=512M \
    PUID=1000 \
    PGID=1000 \
    TZ=UTC \
    REAL_IP_FROM=100.64.0.0/10 \
    APP_TRUSTED_PROXIES=10.0.0.0/8,100.64.0.0/10

COPY --chmod=755 03zz-railway-seed.sh /etc/cont-init.d/03zz-railway-seed.sh
COPY --chmod=755 04-svc-main.sh /etc/cont-init.d/04-svc-main.sh
COPY --chmod=755 07-svc-cron.sh /etc/cont-init.d/07-svc-cron.sh
