#!/usr/bin/with-contenv sh
# Railway template: seed the initial admin account deterministically.
#
# The upstream first-run wizard is unreliable on Railway (template deploys
# boot the container twice and the wizard gate lives only in the first
# boot), so the template bakes a per-deploy ADMIN_PASSWORD (a Railway
# ${{secret(24)}} expression, visible in the service's Variables tab) and
# creates user "admin" here, right after migrations, before the web UI
# starts. Idempotent: skipped when an admin already exists.
set -e

if [ -f /data/.admin-seeded ]; then
  exit 0
fi

PW="${ADMIN_PASSWORD:-}"
if [ -z "$PW" ]; then
  echo "[railway] ADMIN_PASSWORD not set; skipping admin seed"
  exit 0
fi

dbcmd="mariadb -h ${DB_HOST} -P ${DB_PORT:-3306} -u ${DB_USER} -p${DB_PASSWORD}"
count=$(echo 'SELECT COUNT(*) FROM users;' | ${dbcmd} "$DB_NAME" 2>/dev/null | tail -1)
if [ "${count:-0}" != "0" ]; then
  echo "[railway] users already exist; skipping admin seed"
  touch /data/.admin-seeded
  exit 0
fi

echo "[railway] seeding admin user..."
su -s /bin/bash librenms -c "php /opt/librenms/artisan user:add -e admin@example.com -p '$PW' -r admin admin" >/dev/null 2>&1 \
  && touch /data/.admin-seeded \
  && echo "[railway] admin created - user: admin, password: ADMIN_PASSWORD variable" \
  || echo "[railway] admin seed failed (will retry next boot)"
