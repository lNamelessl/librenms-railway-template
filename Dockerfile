# Railway template wrapper for the official LibreNMS image.
# Bakes the template's default configuration as image ENV so deploys need
# zero manual inputs; per-deploy secrets and hostnames stay as Railway
# expression variables. Nothing else is modified. Pin follows upstream.
FROM librenms/librenms:26.8.2

ENV DB_NAME=librenms \
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

COPY railway-seed.sh /etc/cont-init.d/03zz-railway-seed.sh
RUN chmod +x /etc/cont-init.d/03zz-railway-seed.sh
