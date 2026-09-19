# LibreNMS — Railway Template

One-click [Railway](https://railway.com) template for **[LibreNMS](https://www.librenms.org)** — the standard open-source network monitoring system: full SNMP auto-discovery, polling, alerting, and graphs.

**Deploy:** via the Railway template page (3 services: `librenms` + `mariadb` + `redis`).

## Architecture

| Service | Image (pinned) | Notes |
|---|---|---|
| `librenms` | `librenms/librenms:26.8.2` | Web UI on **8000** + **internal poller** (cron `artisan schedule:run` every minute) + `snmpd`; volume on `/data` |
| `mariadb` | `mariadb:10.11` | LibreNMS requires MariaDB ≥ 10.5; `utf8mb4`, DB `librenms`, user `librenms` |
| `redis` | `redis:7.2-alpine` | Session + cache driver (upstream compose defaults), internal network only |

### Poller-in-main-service design (why there is no dispatcher sidecar)

The official [librenms/docker](https://github.com/librenms/docker) compose example ships a **dispatcher sidecar** sharing the `/data` volume. Railway enforces **one volume per service**, so a shared-volume sidecar is impossible there — and it is also unnecessary:

- `SIDECAR_DISPATCHER` defaults to `0`. Verified from image source (`rootfs/etc/cont-init.d/07-svc-cron.sh`): the main container installs cron (`daily.sh` + `artisan schedule:run` every minute) and **runs the poller itself**; the cron service is only disabled when a container *is* a sidecar (`SIDECAR_DISPATCHER=1`).
- The dispatcher service (`librenms-service.py`) is an optional distributed-polling/scaling mechanism, not a requirement.

**Scaling:** deploy additional instances of this template (each is an independent poller with its own DB/Redis), or point extra pollers at the same DB using `DISPATCHER_NODE_ID` — do not try to share one Railway volume between services.

### First boot

1. The container waits for MariaDB, then runs `lnms migrate --force` + `db:seed` automatically (fresh DB ⇒ the web **install wizard** is enabled: `INSTALL=user,finish`).
2. Open the public URL → create your **admin account** in the first-run wizard (alternative: `railway ssh` into the service and run `lnms user:create`).
3. Add your first device (Devices → Add Device) with its SNMP community, or as a ping-only check.

### Resource guidance

- **Give the `librenms` service ≥ 2 GB RAM** (256 MB+ PHP `MEMORY_LIMIT` is pre-set to `512M`). Network monitoring is memory-hungry; smaller instances will OOM during discovery of large device counts.
- Volume `/data` holds RRDs, logs, and config (incl. the generated `APP_KEY`); it is chowned to `PUID`/`PGID` (1000:1000) at boot by the image's init scripts.

## Environment contract

Wired automatically by the template (no manual setup):

- `DB_HOST` / `DB_PORT` / `DB_NAME` / `DB_USER` / `DB_PASSWORD` → MariaDB service (password auto-generated per deploy via `${{secret(24)}}` and shared by reference)
- `REDIS_HOST` / `REDIS_PORT` → Redis service, `CACHE_DRIVER=redis`, `SESSION_DRIVER=redis`
- `LIBRENMS_BASE_URL` → your Railway domain
- `MEMORY_LIMIT=512M`, `PUID=1000`, `PGID=1000`, `TZ=UTC` (adjust after deploy)
- `APP_TRUSTED_PROXIES=10.0.0.0/8,100.64.0.0/10` — Railway's edge proxy originates from CGNAT space; this keeps real client IPs and secure cookies working behind the platform proxy

## Troubleshooting

- **Deploy loops / DB errors on first boot**: first boot runs full schema migrations — allow several minutes before judging health; MariaDB must be up first (the container retries for `DB_TIMEOUT` seconds).
- **Permission errors in logs**: `/data` must be writable by `PUID`/`PGID` (1000:1000). The image fixes ownership on boot; don't mount over `/data` with a read-only source.
- **Devices not polling**: check SNMP reachability — Railway has **no outbound SNMP restriction but no inbound UDP either**; poll devices you can reach over the network, or add ping-only (`snmp_disable`) checks for hosts on Railway's private network (e.g. the MariaDB service hostname).
- **Validation**: `railway ssh` into the `librenms` service and run `php validate.php` (as user `librenms`) for the built-in acceptance check.

## References

- Upstream: https://github.com/librenms/docker · Docs: https://docs.librenms.org
- License: LibreNMS is GPLv3; this template only wires the official image.
