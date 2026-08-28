#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture="$repo_root/tests/banner-authorization-migration/routes.tsv"
before="$repo_root/tests/banner-authorization-migration/before.sql"
add_migration="$repo_root/Baseline/auth/V6__ADD_BANNER_MANAGEMENT_ACCESS_RULE.sql"
expand_migration="$repo_root/Baseline/auth/V7__EXPAND_BANNER_MANAGEMENT_ACCESS_RULE.sql"
reorder_migration="$repo_root/Baseline/auth/V8__AUTHORIZE_BANNER_REORDER.sql"
disable_migration="$repo_root/Baseline/auth/V9__ALLOW_BANNER_DISABLE_ROUTE.sql"
archive_migration="$repo_root/Baseline/auth/V10__ALLOW_BANNER_ARCHIVE_ROUTE.sql"
container="banner-auth-aio-${GITHUB_RUN_ID:-local}-$$"
password="banner-auth-test"

for file in "$fixture" "$before" "$add_migration" "$expand_migration" "$reorder_migration" "$disable_migration" "$archive_migration"; do
  test -f "$file" || { echo "Missing required file: $file" >&2; exit 1; }
done
paths=(
  "$(realpath "$add_migration")" "$(realpath "$expand_migration")" "$(realpath "$reorder_migration")"
  "$(realpath "$disable_migration")" "$(realpath "$archive_migration")"
)
test "$(printf '%s\n' "${paths[@]}" | sort -u | wc -l | tr -d ' ')" = "5"

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

mysql_exec < "$before"
mysql_exec < "$add_migration"
mysql_exec -e "UPDATE auth.access_rule SET value = 'unexpected-pre-expansion-value' WHERE name = 'AR_BANNER_MANAGEMENT_GATEWAY';"
mysql_exec < "$expand_migration"
mysql_exec -e "UPDATE auth.access_rule SET value = 'unexpected-pre-reorder-value' WHERE name = 'AR_BANNER_MANAGEMENT_GATEWAY';"
mysql_exec < "$reorder_migration"
mysql_exec -e "UPDATE auth.access_rule SET value = 'unexpected-pre-disable-value' WHERE name = 'AR_BANNER_MANAGEMENT_GATEWAY';"
mysql_exec < "$disable_migration"
mysql_exec -e "UPDATE auth.access_rule SET value = 'unexpected-pre-archive-value' WHERE name = 'AR_BANNER_MANAGEMENT_GATEWAY';"
mysql_exec < "$archive_migration"

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

python3 - "$pattern" "$fixture" <<'PY'
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

echo "AIO banner authorization migration verified"
