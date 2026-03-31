#!/usr/bin/env bash
set -euo pipefail

MSSQL_HOST="${MSSQL_HOST:-db}"
MSSQL_PORT="${MSSQL_PORT:-1433}"
MSSQL_USER="${MSSQL_USER:-sa}"
MSSQL_PASSWORD="${MSSQL_PASSWORD:-${MSSQL_SA_PASSWORD:-}}"
DB_NAME="${DB_NAME:-RESTAURANT}"
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

echo "Checking if schema already exists..."
HAS_TABLES="$("${SQLCMD_CONN[@]}" -d "$DB_NAME" -h -1 -W -Q "SET NOCOUNT ON; IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='dbo' AND TABLE_NAME='Orders') SELECT 1 ELSE SELECT 0;" | tr -d '\r' | tail -n 1)"

if [[ "$HAS_TABLES" == "1" ]]; then
  echo "Schema already present; skipping ${SCHEMA_SCRIPT}."
  exit 0
fi

if [[ ! -f "$SCHEMA_SCRIPT" ]]; then
  echo "Schema script not found: $SCHEMA_SCRIPT" >&2
  exit 1
fi

echo "Applying schema from ${SCHEMA_SCRIPT}..."
"${SQLCMD_CONN[@]}" -i "$SCHEMA_SCRIPT" -b

echo "DB init done."
