#!/usr/bin/env bash
set -euo pipefail

MSSQL_HOST="${MSSQL_HOST:-db}"
MSSQL_PORT="${MSSQL_PORT:-1433}"
MSSQL_USER="${MSSQL_USER:-sa}"
MSSQL_PASSWORD="${MSSQL_PASSWORD:-${MSSQL_SA_PASSWORD:-}}"
DB_NAME="${DB_NAME:-RESTAURANT}"
SERVICE_DATABASES="${SERVICE_DATABASES:-RESTAURANT_CATALOG,RESTAURANT_ORDERS,RESTAURANT_CUSTOMERS,RESTAURANT_IDENTITY,RESTAURANT_BILLING}"
SCHEMA_SCRIPT="${SCHEMA_SCRIPT:-/scripts/localdb.sql}"

if [[ -z "${MSSQL_PASSWORD}" ]]; then
  echo "Missing MSSQL password. Set MSSQL_PASSWORD or MSSQL_SA_PASSWORD." >&2
  exit 1
fi

SQLCMD=""
for candidate in /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd sqlcmd; do
  if command -v "$candidate" >/dev/null 2>&1; then
    SQLCMD="$candidate"
    break
  fi
done

if [[ -z "$SQLCMD" ]]; then
  echo "sqlcmd not found in container." >&2
  exit 1
fi

echo "Waiting for SQL Server at ${MSSQL_HOST}:${MSSQL_PORT}..."
SQLCMD_CONN=("$SQLCMD" -S "${MSSQL_HOST},${MSSQL_PORT}" -U "$MSSQL_USER" -P "$MSSQL_PASSWORD")
# sqlcmd 18+ enforces encryption by default; trust local/dev cert to allow bootstrap.
if "$SQLCMD" -? 2>&1 | grep -q -- '-C'; then
  SQLCMD_CONN+=(-C)
fi

for i in {1..60}; do
  if "${SQLCMD_CONN[@]}" -Q "SELECT 1" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "Ensuring database ${DB_NAME} exists..."
"${SQLCMD_CONN[@]}" -Q "IF DB_ID('$(echo "$DB_NAME")') IS NULL CREATE DATABASE [$DB_NAME];"

IFS=',' read -r -a SERVICE_DATABASE_ARRAY <<< "$SERVICE_DATABASES"

for service_db in "${SERVICE_DATABASE_ARRAY[@]}"; do
  service_db="$(echo "$service_db" | xargs)"
  if [[ -z "$service_db" ]]; then
    continue
  fi
  echo "Ensuring service database ${service_db} exists..."
  "${SQLCMD_CONN[@]}" -Q "IF DB_ID('$(echo "$service_db")') IS NULL CREATE DATABASE [$service_db];"
done

echo "Checking if schema already exists..."
HAS_TABLES="$("${SQLCMD_CONN[@]}" -d "$DB_NAME" -h -1 -W -Q "SET NOCOUNT ON; IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='dbo' AND TABLE_NAME='Orders') SELECT 1 ELSE SELECT 0;" | tr -d '\r' | tail -n 1)"

if [[ "$HAS_TABLES" == "1" ]]; then
  echo "Schema already present; skipping ${SCHEMA_SCRIPT}."
else
  if [[ ! -f "$SCHEMA_SCRIPT" ]]; then
    echo "Schema script not found: $SCHEMA_SCRIPT" >&2
    exit 1
  fi

  echo "Applying schema from ${SCHEMA_SCRIPT}..."
  "${SQLCMD_CONN[@]}" -i "$SCHEMA_SCRIPT" -b
fi

SYNC_SQL_FILE="$(mktemp)"
cat > "$SYNC_SQL_FILE" <<SQL
SET NOCOUNT ON;
DECLARE @master sysname = N'${DB_NAME}';
DECLARE @sql nvarchar(max) = N'';

SELECT @sql = @sql +
    N'IF EXISTS (SELECT 1 FROM sys.synonyms WHERE name = N''' + o.name + N''' AND schema_id = SCHEMA_ID(N''dbo'')) ' +
    N'DROP SYNONYM dbo.' + QUOTENAME(o.name) + N';' + CHAR(10)
FROM
(
    SELECT name FROM [${DB_NAME}].sys.tables WHERE schema_id = SCHEMA_ID(N'dbo')
    UNION
    SELECT name FROM [${DB_NAME}].sys.views WHERE schema_id = SCHEMA_ID(N'dbo')
) AS o;

EXEC sp_executesql @sql;
SET @sql = N'';

SELECT @sql = @sql +
    N'CREATE SYNONYM dbo.' + QUOTENAME(o.name) + N' FOR ' + QUOTENAME(@master) + N'.dbo.' + QUOTENAME(o.name) + N';' + CHAR(10)
FROM
(
    SELECT name FROM [${DB_NAME}].sys.tables WHERE schema_id = SCHEMA_ID(N'dbo')
    UNION
    SELECT name FROM [${DB_NAME}].sys.views WHERE schema_id = SCHEMA_ID(N'dbo')
) AS o
ORDER BY o.name;

EXEC sp_executesql @sql;
SQL

for service_db in "${SERVICE_DATABASE_ARRAY[@]}"; do
  service_db="$(echo "$service_db" | xargs)"
  if [[ -z "$service_db" ]]; then
    continue
  fi
  echo "Preparing service database shell: ${service_db}"
  "${SQLCMD_CONN[@]}" -d "$service_db" -i "$SYNC_SQL_FILE" -b
done

rm -f "$SYNC_SQL_FILE"

echo "DB init done."
