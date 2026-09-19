#!/usr/bin/with-contenv sh
# Railway platform notes (seeded once, on first boot, while the DB is fresh):
#
# 1. ICMP: Railway containers do not get CAP_NET_RAW, so fping can never
#    work. LibreNMS defaults to icmp_check=true, which makes the poller
#    abort and mark devices down before SNMP is tried. Seed icmp_check=false
#    so SNMP devices poll cleanly. Lives on the persistent /data volume;
#    users can edit or remove it later.
# 2. Dispatcher worker counts: librenms-service.py sizes its worker pools
#    from the CPU count (16 discovery + 24 poller + 8 services threads on an
#    8-vCPU host). Railway caps containers at 1000 tasks; together with
#    php-fpm that can hit the ceiling ("can't start new thread"). Seed
#    modest pools that still parallelize small-to-medium networks.
set -e

mkdir -p /data/config
if [ ! -f /data/config/zz-railway.yaml ]; then
  echo "[railway] seeding icmp_check=false (no CAP_NET_RAW on Railway)"
  printf 'icmp_check: false\nservice_poller_workers: 1\nservice_discovery_workers: 1\nservice_services_workers: 1\n' > /data/config/zz-railway.yaml
fi
