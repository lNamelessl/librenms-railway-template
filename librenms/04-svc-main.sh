#!/usr/bin/with-contenv bash
# shellcheck shell=bash
set -e

# From https://github.com/docker-library/mariadb/blob/master/docker-entrypoint.sh#L21-L41
# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"
  if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
    echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
    exit 1
  fi
  local val="$def"
  if [ "${!var:-}" ]; then
    val="${!var}"
  elif [ "${!fileVar:-}" ]; then
    val="$(<"${!fileVar}")"
  fi
  export "$var"="$val"
  unset "$fileVar"
}

DB_PORT=${DB_PORT:-3306}
DB_NAME=${DB_NAME:-librenms}
DB_USER=${DB_USER:-librenms}
DB_TIMEOUT=${DB_TIMEOUT:-60}

# Railway single-container variant (template note):
# Upstream turns the container into a dispatcher-only sidecar when
# SIDECAR_DISPATCHER=1 (skipping web + snmpd). On Railway, one volume per
# service forbids sidecars, so the main container must run EVERYTHING:
# web (nginx/php-fpm), snmpd, cron AND the dispatcher. We therefore only
# skip for the other sidecar roles, never for the dispatcher.
SIDECAR_SYSLOGNG=${SIDECAR_SYSLOGNG:-0}
SIDECAR_SNMPTRAPD=${SIDECAR_SNMPTRAPD:-0}

if [ "$SIDECAR_SYSLOGNG" = "1" ] || [ "$SIDECAR_SNMPTRAPD" = "1" ]; then
  exit 0
fi

# Handle .env
if [ ! -f "/data/.env" ]; then
  echo "Generating APP_KEY and unique NODE_ID"
  cat >"/data/.env" <<EOL
APP_KEY=$(artisan key:generate --no-interaction --force --show)
NODE_ID=$(php -r "echo uniqid();")
EOL
fi
cat "/data/.env" >>"${LIBRENMS_PATH}/.env"
chown librenms:librenms /data/.env "${LIBRENMS_PATH}/.env"

file_env 'DB_PASSWORD'
if [ -z "$DB_PASSWORD" ]; then
  echo >&2 "ERROR: Either DB_PASSWORD or DB_PASSWORD_FILE must be defined"
  exit 1
fi

dbcmd="mariadb -h ${DB_HOST} -P ${DB_PORT} -u "${DB_USER}" "-p${DB_PASSWORD}""
unset DB_PASSWORD

echo "Waiting ${DB_TIMEOUT}s for database to be ready..."
counter=1
while ! ${dbcmd} -e "show databases;" >/dev/null 2>&1; do
  sleep 1
  counter=$((counter + 1))
  if [ ${counter} -gt ${DB_TIMEOUT} ]; then
    echo >&2 "ERROR: Failed to connect to database on $DB_HOST"
    exit 1
  fi
done
echo "Database ready!"

# Railway template: no first-run wizard. Railway template deploys boot the
# container twice (config pass after first boot), and the wizard gate only
# survives the first boot - the admin account is seeded deterministically
# by 04zz-railway-admin.sh below instead.

echo "Updating database schema..."
lnms migrate --force --no-ansi --no-interaction
artisan db:seed --force --no-ansi --no-interaction

echo "Clear cache"
artisan cache:clear --no-interaction
artisan config:cache --no-interaction

# Railway template: seed the admin account deterministically (see
# 04zz-railway-admin.sh; runs after migrations, before the web UI starts).
if [ -n "${ADMIN_PASSWORD:-}" ] && [ -f /etc/cont-init.d/04zz-railway-admin.sh ]; then
  /etc/cont-init.d/04zz-railway-admin.sh || echo "[railway] admin seed failed (non-fatal)"
fi

mkdir -p /etc/services.d/nginx
cat >/etc/services.d/nginx/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
s6-setuidgid ${PUID}:${PGID}
nginx -g "daemon off;"
EOL
chmod +x /etc/services.d/nginx/run

mkdir -p /etc/services.d/php-fpm
cat >/etc/services.d/php-fpm/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
s6-setuidgid ${PUID}:${PGID}
php-fpm84 -F
EOL
chmod +x /etc/services.d/php-fpm/run

mkdir -p /etc/services.d/snmpd
cat >/etc/services.d/snmpd/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
/usr/sbin/snmpd -f -c /etc/snmp/snmpd.conf
EOL
chmod +x /etc/services.d/snmpd/run
