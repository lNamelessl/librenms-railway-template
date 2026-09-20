# LibreNMS Railway template image — thin wrapper around the pinned official image.
#
# Why a wrapper? Railway enforces one volume per service, so the upstream
# dispatcher SIDECAR (which shares /data) cannot be deployed there. This
# image consolidates the upstream compose topology into a single container:
#   - SIDECAR_DISPATCHER=1 starts librenms-service.py (the poller/discovery
#     dispatcher — in LibreNMS 26.x the cron scheduler alone never runs
#     device polls; a dispatcher is mandatory, per upstream README)
#   - adapted 04-svc-main.sh + 07-svc-cron.sh keep web (nginx/php-fpm),
#     snmpd and cron alive alongside the dispatcher (upstream would strip
#     them for sidecar roles)
#   - a first-boot seed sets icmp_check=false (Railway containers run
#     without CAP_NET_RAW, so fping can never work) and modest dispatcher
#     worker pools (Railway caps containers at 1000 tasks; CPU-sized
#     defaults crash with "can't start new thread")
# Env defaults are baked here (not template variables) so the marketplace
# deploy needs zero form inputs; each can be overridden after deploy.
FROM librenms/librenms:26.8.2

ENV SIDECAR_DISPATCHER=1 \
    DISPATCHER_NODE_ID=railway-main \
    MEMORY_LIMIT=512M \
    CACHE_DRIVER=redis \
    SESSION_DRIVER=redis \
    CACHE_STORE=redis \
    PORT=8000 \
    FPM_PM_MAX_CHILDREN=4 \
    FPM_PM_START_SERVERS=2 \
    FPM_PM_MIN_SPARE_SERVERS=2 \
    FPM_PM_MAX_SPARE_SERVERS=4

COPY --chmod=755 03zz-railway-seed.sh /etc/cont-init.d/03zz-railway-seed.sh
COPY --chmod=755 04-svc-main.sh /etc/cont-init.d/04-svc-main.sh
COPY --chmod=755 07-svc-cron.sh /etc/cont-init.d/07-svc-cron.sh
