# Thin wrapper around the pinned official LibreNMS image.
# Adds one first-boot seed script that sets icmp_check=false:
# Railway containers run without CAP_NET_RAW, so ICMP (fping) can never
# succeed there; without this, SNMP devices are marked down before SNMP
# is ever tried. Everything else is stock upstream behavior.
FROM librenms/librenms:26.8.2
COPY --chmod=755 03zz-railway-seed.sh /etc/cont-init.d/03zz-railway-seed.sh
