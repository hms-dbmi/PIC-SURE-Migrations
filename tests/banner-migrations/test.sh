#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_dir="$repo_root/tests/banner-migrations"
routes_fixture="$test_dir/routes.tsv"
schema_fixture="$test_dir/banner-schema.tsv"
before="$test_dir/before.sql"
auth_migration="$repo_root/Baseline/auth/V7__ADD_BANNER_MANAGEMENT_ACCESS_RULE.sql"
picsure_migration="$repo_root/Baseline/picsure/V10__CREATE_BANNER_TABLES.sql"
container="banner-migrations-${GITHUB_RUN_ID:-local}-$$"
password="banner-migrations-test"

for file in "$routes_fixture" "$schema_fixture" "$before" "$auth_migration" "$picsure_migration"; do
  test -f "$file" || { echo "Missing required file: $file" >&2; exit 1; }
done

cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --name "$container" -e MYSQL_ROOT_PASSWORD="$password" -d mysql:8.0 >/dev/null
for _ in {1..60}; do
  if docker exec "$container" mysql -uroot -p"$password" -e "SELECT 1" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
docker exec "$container" mysql -uroot -p"$password" -e "SELECT 1" >/dev/null

mysql_exec() {
  docker exec -i "$container" mysql -uroot -p"$password" --batch --skip-column-names "$@"
}

# Auth: apply the access-rule migration and verify the gateway pattern and role grants.
mysql_exec < "$before"
mysql_exec < "$auth_migration"

pattern="$(mysql_exec -e "SELECT value FROM auth.access_rule WHERE name = 'AR_BANNER_MANAGEMENT_GATEWAY';")"
granted_roles="$(mysql_exec -e "
  SELECT GROUP_CONCAT(r.name ORDER BY r.name SEPARATOR ',')
  FROM auth.role r
  JOIN auth.role_privilege rp ON rp.role_id = r.uuid
  JOIN auth.privilege p ON p.uuid = rp.privilege_id
  WHERE p.name = 'BANNER_MANAGEMENT';")"
test "$granted_roles" = "Admin,PIC-SURE Top Admin"
test "$(mysql_exec -e "
  SELECT COUNT(*) FROM auth.role r
  JOIN auth.role_privilege rp ON rp.role_id = r.uuid
  JOIN auth.privilege p ON p.uuid = rp.privilege_id
  WHERE r.name = 'PIC-SURE User' AND p.name = 'BANNER_MANAGEMENT';")" = "0"

python3 - "$pattern" "$routes_fixture" <<'PY'
import re
import sys
from pathlib import Path

actual_pattern = sys.argv[1]
entries = [line.split("\t", 1) for line in Path(sys.argv[2]).read_text().splitlines()]
expected_pattern = next(value for kind, value in entries if kind == "pattern")
assert actual_pattern == expected_pattern, (actual_pattern, expected_pattern)
rule = re.compile(actual_pattern)
for kind, route in entries:
    if kind == "allow":
        assert rule.fullmatch(route), f"expected allowed route: {route}"
    elif kind == "deny":
        assert not rule.fullmatch(route), f"expected denied route: {route}"
PY

# Picsure: apply the schema migration and verify the banner tables and allocator seed.
mysql_exec -e "DROP DATABASE IF EXISTS picsure; CREATE DATABASE picsure;"
mysql_exec < "$picsure_migration"

actual_schema="$(mysql_exec -e "
  SELECT table_name, ordinal_position, column_name, column_type, is_nullable
  FROM information_schema.columns
  WHERE table_schema = 'picsure'
    AND table_name IN ('banner_occurrence', 'banner_version', 'banner_priority_allocator')
  ORDER BY FIELD(table_name, 'banner_occurrence', 'banner_version', 'banner_priority_allocator'), ordinal_position;")"
diff -u "$schema_fixture" <(printf '%s\n' "$actual_schema")

test "$(mysql_exec -e "SELECT CONCAT(id, ':', next_priority) FROM picsure.banner_priority_allocator;")" = "1:1"

echo "Banner migrations verified"
