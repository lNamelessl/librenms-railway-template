# Railway template wrapper for the official LibreNMS image.
# Adds one first-boot init step; nothing else is modified.
# Pin follows the official image version.
FROM librenms/librenms:26.8.2

COPY railway-seed.sh /etc/cont-init.d/03zz-railway-seed.sh
RUN chmod +x /etc/cont-init.d/03zz-railway-seed.sh
