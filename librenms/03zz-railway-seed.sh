#!/usr/bin/with-contenv sh
# Railway platform note: Railway containers do not get CAP_NET_RAW, so
# ICMP (fping) can never work there. LibreNMS defaults to icmp_check=true,
# which makes the poller abort and mark devices down before SNMP is tried.
# Seed icmp_check=false once, on first boot, so SNMP devices poll cleanly.
# The file lives on the persistent /data volume, so users can edit or
# remove it later; ConfigSeeder only applies it while the DB is fresh.
set -e

mkdir -p /data/config
if [ ! -f /data/config/zz-railway.yaml ]; then
  echo "[railway] seeding icmp_check=false (no CAP_NET_RAW on Railway)"
  printf 'icmp_check: false\n' > /data/config/zz-railway.yaml
fi
