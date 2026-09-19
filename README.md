# LibreNMS — Railway Template

One-click [Railway](https://railway.com) template for **[LibreNMS](https://www.librenms.org)** — the standard open-source network monitoring system: full SNMP auto-discovery, polling, alerting, and graphs.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/librenms-template-2)

Three services: `librenms` + `mariadb` + `redis`. Zero deploy-form inputs — credentials are generated per deploy, everything is wired by reference.

## Architecture

| Service | Image (pinned) | Notes |
|---|---|---|
| `librenms` | [`librenms/librenms:26.8.2`](librenms/) + thin Railway wrapper | Web UI on **8000** + poller **dispatcher** + cron scheduler + `snmpd`; persistent volume on `/data` |
| `mariadb` | `mariadb:10.11` | LibreNMS requires MariaDB ≥ 10.5; started with `utf8mb4` / `utf8mb4_unicode_ci` / `lower_case_table_names=0`; DB `librenms`, user `librenms` |
| `redis` | `redis:7.2-alpine` | Dispatcher queues/locks, sessions, cache; internal network only |

### Poller topology (why the dispatcher lives in the main container)

The official [librenms/docker](https://github.com/librenms/docker) compose example ships a **dispatcher sidecar** sharing the `/data` volume. Railway enforces **one volume per service**, so a shared-volume sidecar is impossible there. Verified against the LibreNMS 26.x image source: the Laravel scheduler (`cron` → `artisan schedule:run`) only *schedules* work — **device polls are executed by the dispatcher service (`librenms-service.py`)**, and upstream disables web/cron in any container where the dispatcher runs. A sidecar is therefore not optional on upstream topologies.

This template's wrapper image (3 KB of scripts over the official image) consolidates the whole upstream compose topology into the single `librenms` service:

- `SIDECAR_DISPATCHER=1` + `DISPATCHER_NODE_ID=railway-main` start the dispatcher, which registers in `poller_cluster` and shows as *enabled* in `php validate.php`.
- Adapted `04-svc-main.sh` + `07-svc-cron.sh` keep nginx/php-fpm, `snmpd`, and cron (`daily.sh` + the Laravel scheduler) running **alongside** the dispatcher — upstream would strip them for sidecar roles.
- A first-boot seed writes `icmp_check=false` (persisted on the volume): Railway containers run without `CAP_NET_RAW`, so `fping` can never work; without this, SNMP devices are marked down before SNMP is ever tried.

**Scaling:** deploy additional instances of this template (each is an independent poller with its own DB/Redis), or point extra dispatcher containers at the same DB/Redis using `DISPATCHER_NODE_ID` — do not try to share one Railway volume between services.

### First boot

1. The container waits for MariaDB, then runs `lnms migrate --force` + `db:seed` automatically (fresh DB ⇒ the web **install wizard** is enabled: `INSTALL=user,finish`).
2. Open the public URL → create your **admin account** in the first-run wizard (alternative: `railway ssh` into the service and run `php lnms user:add -n --role admin USERNAME`).
3. Add your first device (Devices → Add Device) with its SNMP community — tick *force add* if it doesn't answer ping. Smoke test: the bundled `snmpd` answers on `localhost` with community `librenmsdocker`.

### Resource guidance

- **Give the `librenms` service ≥ 2 GB RAM** (PHP `MEMORY_LIMIT` is pre-set to `512M`). Network monitoring is memory-hungry; smaller instances will OOM during discovery of large device counts.
- Volume `/data` holds RRDs, logs, and config (incl. the generated `APP_KEY`); it is chowned to `PUID`/`PGID` (1000:1000) at boot by the image's init scripts.

## Environment contract

Wired automatically by the template (no deploy-time input needed):

- `DB_HOST` → `${{mariadb.RAILWAY_PRIVATE_DOMAIN}}`, `DB_PASSWORD` → `${{secret(24)}}` (generated per deploy; the MariaDB service's `MYSQL_PASSWORD` references the same value)
- `REDIS_HOST` → `${{redis.RAILWAY_PRIVATE_DOMAIN}}`
- `LIBRENMS_BASE_URL` → `https://${{RAILWAY_PUBLIC_DOMAIN}}`
- `CACHE_DRIVER=redis`, `SESSION_DRIVER=redis`, `CACHE_STORE=redis`, `MEMORY_LIMIT=512M`, `PORT=8000`, `PUID=1000`, `PGID=1000`, `TZ=UTC` are baked as image defaults in the wrapper Dockerfile — override any of them with a normal Railway variable after deploy.
- `APP_TRUSTED_PROXIES=10.0.0.0/8,100.64.0.0/10` — Railway's edge proxy originates from CGNAT space; this keeps real client IPs and secure cookies working behind the platform proxy.

## Troubleshooting

- **Deploy loops / DB errors on first boot**: first boot runs full schema migrations — allow several minutes before judging health; MariaDB must be up first (the container retries for `DB_TIMEOUT` seconds).
- **Permission errors in logs**: `/data` must be writable by `PUID`/`PGID` (1000:1000). The image fixes ownership on boot; don't mount over `/data` with a read-only source.
- **Devices not polling**: devices must be SNMP-reachable from Railway (outbound UDP works; LAN-private devices do not). Ping-only (`snmp_disable`) devices **cannot** work on Railway — containers lack `CAP_NET_RAW`, so ICMP is unavailable; the template pre-sets `icmp_check=false` so SNMP availability decides up/down instead. The `fping` FAILs in `php validate.php` are this platform limitation and are expected.
- **Validation**: `railway ssh` into the `librenms` service and run `php validate.php` (as user `librenms`) for the built-in acceptance check.

## References

- Upstream: https://github.com/librenms/docker · Docs: https://docs.librenms.org
- License: LibreNMS is GPLv3; this template only wires the official image.
