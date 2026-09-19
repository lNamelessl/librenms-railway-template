# Railway template wrapper for MariaDB (LibreNMS requires MariaDB >= 10.5).
# Bakes the upstream librenms/docker compose flags and defaults so the
# marketplace deploy needs zero manual inputs. The librenms user's password
# is NOT set here — it comes from the shared DB_PASSWORD expression variable.
FROM mariadb:10.11

ENV MARIADB_RANDOM_ROOT_PASSWORD=yes \
    MYSQL_DATABASE=librenms \
    MYSQL_USER=librenms \
    MARIADB_AUTO_UPGRADE=yes \
    TZ=UTC

CMD ["mariadbd", "--innodb-file-per-table=1", "--lower-case-table-names=0", "--character-set-server=utf8mb4", "--collation-server=utf8mb4_unicode_ci"]
