#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_dir="$repo_root/tests/aio-deployment-migration"
cell="${1:-all}"

mysql_image="mysql:8.0.43@sha256:ccf4fed7ff4b886aeb3573a1f5d5b509525ecff55a2d1e2653c27a5abdded309"
flyway_image="flyway/flyway:11.7.2"
release_control_url="https://github.com/hms-dbmi/baseline-pic-sure-release-control.git"
psama_url="https://github.com/hms-dbmi/pic-sure-auth-microapp.git"
psa_url="https://github.com/hms-dbmi/pic-sure.git"
psm_url="https://github.com/hms-dbmi/PIC-SURE-Migrations.git"
release_control_sha="78c8a9efde3989afae9f137dac583c739667f59d"
psama_tag="v4.2.2"
psama_tag_sha="67dd3cc549c60388d200ac7078ef53c6c676a95d"
psama_sha="ca8ac3641ba122a93cda8a5d7cad7f23f7a46bb6"
psa_tag="v2.27.2"
psa_sha="88a767c273af776ca1edeb7be4d4365393e376f7"
psm_tag="v1.0.5"
psm_sha="84ad03076ce9f69f27ebb51d0efa5d3d43114ea4"
application_uuid="11111111111111111111111111111111"
resource_uuid="22222222222222222222222222222222"
password="aio-banner-proof"
test_id="aio-banner-$PPID-$$"
network_name="$test_id-network"
mysql_container="$test_id-mysql"
tmp_parent="${TMPDIR:-/tmp}"
tmp_parent="${tmp_parent%/}"
tmp_root="$(mktemp -d "$tmp_parent/$test_id.XXXXXX")"
executed_results="$tmp_root/executed-results.tsv"
source_root="${AIO_PROOF_SOURCE_ROOT:-$tmp_root/sources}"

cleanup() {
    docker rm -f "$mysql_container" >/dev/null 2>&1 || true
    docker network rm "$network_name" >/dev/null 2>&1 || true
    case "$tmp_root" in
        "$tmp_parent"/aio-banner-*) rm -rf -- "$tmp_root" ;;
        *) echo "Refusing to remove unexpected temporary directory: $tmp_root" >&2 ;;
    esac
}
trap cleanup EXIT

case "$cell" in
    all|fresh|supported-upgrade|occurrence-only) ;;
    *)
        echo "usage: $0 [all|fresh|supported-upgrade|occurrence-only]" >&2
        exit 2
        ;;
esac

required_files=(
    "$test_dir/matrix.tsv"
    "$test_dir/feature-sql.sha256"
    "$test_dir/occurrence-intermediate-sql.sha256"
    "$test_dir/banner-schema.tsv"
    "$test_dir/supported-data.sql"
    "$test_dir/occurrence-only.sql"
    "$repo_root/tests/banner-authorization-migration/test.sh"
    "$repo_root/tests/banner-version-migration/test.sh"
)
for file in "${required_files[@]}"; do
    test -f "$file" || { echo "Missing required file: $file" >&2; exit 2; }
done

retry() {
    local description="$1"
    local attempt
    shift

    for attempt in 1 2 3; do
        if "$@"; then
            return 0
        fi
        if [[ "$attempt" != 3 ]]; then
            echo "$description failed on attempt $attempt; retrying" >&2
            sleep "$attempt"
        fi
    done
    echo "$description failed after 3 attempts" >&2
    return 1
}

checkout_commit() {
    local url="$1"
    local sha="$2"
    local destination="$3"

    git init --quiet "$destination"
    git -C "$destination" remote add origin "$url"
    retry "Fetching $url at $sha" \
        git -C "$destination" fetch --quiet --depth 1 origin "$sha"
    git -C "$destination" checkout --quiet --detach FETCH_HEAD
}

checkout_tag() {
    local url="$1"
    local tag="$2"
    local destination="$3"

    git init --quiet "$destination"
    git -C "$destination" remote add origin "$url"
    retry "Fetching $url tag $tag" \
        git -C "$destination" fetch --quiet --depth 1 origin \
        "refs/tags/$tag:refs/tags/$tag"
    git -C "$destination" checkout --quiet --detach "$tag^{commit}"
}

assert_checkout() {
    local label="$1"
    local checkout="$2"
    local expected_sha="$3"
    local actual_sha
    local status

    actual_sha="$(git -C "$checkout" rev-parse HEAD 2>/dev/null)" || {
        echo "$label is not a Git checkout: $checkout" >&2
        exit 1
    }
    if [[ "$actual_sha" != "$expected_sha" ]]; then
        echo "$label checkout SHA mismatch: expected $expected_sha, got $actual_sha" >&2
        exit 1
    fi
    if git -C "$checkout" symbolic-ref --quiet HEAD >/dev/null; then
        echo "$label checkout must be detached at $expected_sha" >&2
        exit 1
    fi
    status="$(git -C "$checkout" status --porcelain --untracked-files=all)"
    if [[ -n "$status" ]]; then
        echo "$label checkout contains modified or untracked inputs:" >&2
        printf '%s\n' "$status" >&2
        exit 1
    fi
}

assert_tag() {
    local label="$1"
    local checkout="$2"
    local tag="$3"
    local expected_tag_sha="$4"
    local expected_commit_sha="$5"
    local actual_tag_sha
    local actual_commit_sha

    actual_tag_sha="$(git -C "$checkout" rev-parse "refs/tags/$tag" 2>/dev/null)" || {
        echo "$label checkout is missing tag $tag" >&2
        exit 1
    }
    actual_commit_sha="$(git -C "$checkout" rev-parse "refs/tags/$tag^{commit}" 2>/dev/null)" || {
        echo "$label tag $tag does not resolve to a commit" >&2
        exit 1
    }
    if [[ "$actual_tag_sha" != "$expected_tag_sha" ]]; then
        echo "$label tag $tag mismatch: expected $expected_tag_sha, got $actual_tag_sha" >&2
        exit 1
    fi
    if [[ "$actual_commit_sha" != "$expected_commit_sha" ]]; then
        echo "$label tag $tag commit mismatch: expected $expected_commit_sha, got $actual_commit_sha" >&2
        exit 1
    fi
}

prepare_sources() {
    if [[ -z "${AIO_PROOF_SOURCE_ROOT:-}" ]]; then
        mkdir -p "$source_root"
        checkout_commit "$release_control_url" \
            "$release_control_sha" "$source_root/release-control"
        checkout_tag "$psama_url" "$psama_tag" "$source_root/psama"
        checkout_tag "$psa_url" "$psa_tag" "$source_root/psa"
        checkout_tag "$psm_url" "$psm_tag" "$source_root/migrations"
    fi

    assert_checkout "Release control" "$source_root/release-control" "$release_control_sha"
    assert_checkout "PSAMA" "$source_root/psama" "$psama_sha"
    assert_checkout "PSA" "$source_root/psa" "$psa_sha"
    assert_checkout "PSM" "$source_root/migrations" "$psm_sha"
    assert_tag "PSAMA" "$source_root/psama" "$psama_tag" "$psama_tag_sha" "$psama_sha"
    assert_tag "PSA" "$source_root/psa" "$psa_tag" "$psa_sha" "$psa_sha"
    assert_tag "PSM" "$source_root/migrations" "$psm_tag" "$psm_sha" "$psm_sha"

    python3 - \
        "$source_root/release-control/build-spec.json" \
        "$psa_tag" \
        "$psama_tag" \
        "$psm_tag" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    builds = {entry["project_job_git_key"]: entry["git_hash"] for entry in json.load(handle)["application"]}

expected = {"PSA": sys.argv[2], "PSAMA": sys.argv[3], "PSM": sys.argv[4]}
actual = {key: builds.get(key) for key in expected}
assert actual == expected, (actual, expected)
PY
}

verify_release_overlap() {
    local section
    local tagged_file
    local name

    for section in auth picsure; do
        for tagged_file in "$source_root/migrations/Baseline/$section"/V*.sql; do
            name="$(basename "$tagged_file")"
            if [[ -f "$repo_root/Baseline/$section/$name" ]]; then
                cmp "$tagged_file" "$repo_root/Baseline/$section/$name" >/dev/null || {
                    echo "Applied release migration changed: Baseline/$section/$name" >&2
                    exit 1
                }
            fi
        done
    done
}

verify_checksum_manifest() {
    local manifest="$1"

    python3 - "$repo_root" "$manifest" <<'PY'
import hashlib
import sys
from pathlib import Path

repo = Path(sys.argv[1])
manifest = Path(sys.argv[2])
for line in manifest.read_text(encoding="utf-8").splitlines():
    expected, relative = line.split("\t", 1)
    actual = hashlib.sha256((repo / relative).read_bytes()).hexdigest()
    assert actual == expected, (relative, actual, expected)
PY
}

verify_matrix_contract() {
    python3 - \
        "$test_dir/matrix.tsv" \
        "$release_control_sha" \
        "PSAMA $psama_tag@$psama_sha V1-V9" \
        "PSA $psa_tag@$psa_sha V1-V8" \
        "$mysql_image" \
        "$flyway_image" <<'PY'
import csv
import sys

expected_header = [
    "deployment", "cell", "starting_state", "forward_migration_range", "release_control_sha",
    "core_auth_source", "core_picsure_source", "custom_start_source", "mysql_image",
    "flyway_test_image", "deployment_migration_image", "deployment_flyway_version",
    "start_custom_auth_max", "start_custom_picsure_max", "final_custom_auth_max",
    "final_custom_picsure_max", "result", "feature_sql_checksum_result", "remaining_assumptions",
]
with open(sys.argv[1], encoding="utf-8", newline="") as handle:
    reader = csv.DictReader(handle, delimiter="\t")
    assert reader.fieldnames == expected_header, reader.fieldnames
    rows = list(reader)

assert [row["cell"] for row in rows] == ["fresh", "supported-upgrade", "occurrence-only"]
release_control_sha, core_auth_source, core_picsure_source, mysql_image, flyway_image = sys.argv[2:]
for row in rows:
    assert row["deployment"] == "AIO"
    assert row["release_control_sha"] == release_control_sha
    assert row["core_auth_source"] == core_auth_source
    assert row["core_picsure_source"] == core_picsure_source
    assert row["mysql_image"] == mysql_image
    assert row["flyway_test_image"] == flyway_image
    assert row["deployment_migration_image"] == "dbmi/pic-sure-db-migrations:pic-sure-db-migration_v1.0"
    assert row["deployment_flyway_version"] == "UNKNOWN"
    for field in (
        "start_custom_auth_max",
        "start_custom_picsure_max",
        "final_custom_auth_max",
        "final_custom_picsure_max",
    ):
        assert row[field] == "NONE" or row[field].isdigit(), (row["cell"], field, row[field])
    assert row["result"] in {"PASS", "FAIL"}
    assert row["feature_sql_checksum_result"] in {"MATCH", "MISMATCH"}
    for field in ("starting_state", "forward_migration_range", "custom_start_source", "remaining_assumptions"):
        assert row[field].strip(), (row["cell"], field)
PY
}

verify_matrix_results() {
    python3 - "$test_dir/matrix.tsv" "$executed_results" "$cell" <<'PY'
import csv
import sys

with open(sys.argv[1], encoding="utf-8", newline="") as handle:
    rows = {row["cell"]: row for row in csv.DictReader(handle, delimiter="\t")}
with open(sys.argv[2], encoding="utf-8", newline="") as handle:
    executed_rows = {row["cell"]: row for row in csv.DictReader(handle, delimiter="\t")}

expected_cells = set(rows) if sys.argv[3] == "all" else {sys.argv[3]}
assert set(executed_rows) == expected_cells, (set(executed_rows), expected_cells)
for cell in expected_cells:
    expected = rows[cell]
    actual = executed_rows[cell]
    for field, value in actual.items():
        if field != "cell":
            assert expected[field] == value, (cell, field, actual[field], expected[field])
PY
}

record_matrix_result() {
    local executed_cell="$1"
    local start_auth_max="$2"
    local start_picsure_max="$3"
    local final_auth_max
    local final_picsure_max

    final_auth_max="$(mysql_exec auth --execute="SELECT MAX(CAST(version AS UNSIGNED)) FROM flyway_custom_schema_history WHERE success=1;")"
    final_picsure_max="$(mysql_exec picsure --execute="SELECT MAX(CAST(version AS UNSIGNED)) FROM flyway_custom_schema_history WHERE success=1;")"

    if [[ ! -f "$executed_results" ]]; then
        printf 'cell\tstart_custom_auth_max\tstart_custom_picsure_max\tfinal_custom_auth_max\tfinal_custom_picsure_max\tresult\tfeature_sql_checksum_result\n' \
            > "$executed_results"
    fi
    printf '%s\t%s\t%s\t%s\t%s\tPASS\tMATCH\n' \
        "$executed_cell" "$start_auth_max" "$start_picsure_max" \
        "$final_auth_max" "$final_picsure_max" >> "$executed_results"
}

start_mysql() {
    local mysql_ready=false

    docker network create "$network_name" >/dev/null
    docker run --detach --name "$mysql_container" --network "$network_name" \
        --env MYSQL_ROOT_PASSWORD="$password" "$mysql_image" >/dev/null

    for _ in {1..60}; do
        if docker exec --env MYSQL_PWD="$password" "$mysql_container" \
            mysqladmin --protocol=TCP --host=127.0.0.1 --user=root ping --silent >/dev/null 2>&1; then
            mysql_ready=true
            break
        fi
        sleep 1
    done
    if [[ "$mysql_ready" != true ]]; then
        echo "MySQL did not accept connections within 60 seconds" >&2
        exit 1
    fi
}

mysql_exec() {
    docker exec --interactive --env MYSQL_PWD="$password" "$mysql_container" \
        mysql --protocol=TCP --host=127.0.0.1 --user=root --batch --skip-column-names "$@"
}

run_flyway() {
    local schema="$1"
    local migrations="$2"
    local history_table="$3"
    local baseline_on_migrate="$4"
    local mount_path
    local flyway_options

    mount_path="$(realpath "$migrations")"
    flyway_options=(
        -url="jdbc:mysql://$mysql_container:3306/$schema?allowPublicKeyRetrieval=true&useSSL=false&serverTimezone=UTC"
        -user=root
        -password="$password"
        -locations=filesystem:/flyway/sql
        -table="$history_table"
        -connectRetries=30
        -validateMigrationNaming=true
    )
    if [[ "$baseline_on_migrate" == true ]]; then
        flyway_options+=(-baselineOnMigrate=true)
    fi

    docker run --rm --network "$network_name" \
        --volume "$mount_path:/flyway/sql:ro" \
        "$flyway_image" \
        "${flyway_options[@]}" migrate
}

reset_databases() {
    mysql_exec --execute="DROP DATABASE IF EXISTS auth; DROP DATABASE IF EXISTS picsure; CREATE DATABASE auth; CREATE DATABASE picsure;"
}

run_core_migrations() {
    run_flyway auth "$source_root/psama/pic-sure-auth-db/db/sql" flyway_schema_history false
    run_flyway picsure "$source_root/psa/pic-sure-api-data/src/main/resources/db/sql" flyway_schema_history false
}

substitute_placeholders() {
    local custom_root="$1"

    python3 - "$custom_root" "$application_uuid" "$resource_uuid" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
application_placeholder = "__APPLICATION_UUID__"
resource_placeholder = "__RESOURCE_UUID__"
auth_files = list((root / "auth").glob("*.sql"))
picsure_files = list((root / "picsure").glob("*.sql"))

wrong_scope = [
    str(path)
    for path in auth_files
    if resource_placeholder in path.read_text(encoding="utf-8")
]
wrong_scope.extend(
    str(path)
    for path in picsure_files
    if application_placeholder in path.read_text(encoding="utf-8")
)
assert not wrong_scope, f"placeholder found in wrong migration directory: {wrong_scope}"

for path in auth_files:
    value = path.read_text(encoding="utf-8")
    path.write_text(
        value.replace(application_placeholder, sys.argv[2]),
        encoding="utf-8",
    )
for path in picsure_files:
    value = path.read_text(encoding="utf-8")
    path.write_text(
        value.replace(resource_placeholder, sys.argv[3]),
        encoding="utf-8",
    )

remaining = [
    str(path)
    for path in root.rglob("*.sql")
    if application_placeholder in path.read_text(encoding="utf-8")
    or resource_placeholder in path.read_text(encoding="utf-8")
]
assert not remaining, remaining
PY
}

copy_custom_set() {
    local source="$1"
    local destination="$2"

    mkdir -p "$destination"
    cp -R "$source/auth" "$destination/auth"
    cp -R "$source/picsure" "$destination/picsure"
    substitute_placeholders "$destination"
}

copy_occurrence_intermediate_set() {
    local destination="$1"

    mkdir -p "$destination/auth" "$destination/picsure"
    cp "$source_root/migrations/Baseline/auth"/V*.sql "$destination/auth/"
    cp "$repo_root/Baseline/picsure"/V{2,3,4,7,8,9,10}__*.sql "$destination/picsure/"
    substitute_placeholders "$destination"
}

run_custom_migrations() {
    local custom_root="$1"

    run_flyway picsure "$custom_root/picsure" flyway_custom_schema_history true
    run_flyway auth "$custom_root/auth" flyway_custom_schema_history true
}

assert_equal() {
    local actual="$1"
    local expected="$2"
    local description="$3"

    if [[ "$actual" != "$expected" ]]; then
        echo "$description: expected '$expected', got '$actual'" >&2
        exit 1
    fi
}

assert_history() {
    local schema="$1"
    local table="$2"
    local expected_max="$3"
    local expected_count="$4"
    local actual

    actual="$(mysql_exec "$schema" --execute="SELECT CONCAT(MAX(CAST(version AS UNSIGNED)), ':', COUNT(*)) FROM $table WHERE success = 1;")"
    assert_equal "$actual" "$expected_max:$expected_count" "$schema.$table history"
}

assert_schema() {
    local actual="$tmp_root/banner-schema.actual.tsv"

    mysql_exec --execute="
        SELECT table_name, ordinal_position, column_name, column_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'picsure'
          AND table_name IN ('banner_occurrence', 'banner_version', 'banner_priority_allocator')
        ORDER BY FIELD(table_name, 'banner_occurrence', 'banner_version', 'banner_priority_allocator'), ordinal_position;
    " > "$actual"
    diff -u "$test_dir/banner-schema.tsv" "$actual"

    assert_equal "$(mysql_exec --execute="
        SELECT CONCAT(
            (SELECT COUNT(*) FROM information_schema.key_column_usage WHERE constraint_schema='picsure' AND table_name='banner_occurrence' AND constraint_name='PRIMARY' AND column_name='uuid' AND ordinal_position=1), ':',
            (SELECT COUNT(*) FROM information_schema.key_column_usage WHERE constraint_schema='picsure' AND table_name='banner_version' AND constraint_name='PRIMARY' AND column_name='uuid' AND ordinal_position=1), ':',
            (SELECT COUNT(*) FROM information_schema.key_column_usage WHERE constraint_schema='picsure' AND table_name='banner_priority_allocator' AND constraint_name='PRIMARY' AND column_name='id' AND ordinal_position=1), ':',
            (SELECT COUNT(*) FROM information_schema.key_column_usage WHERE constraint_schema='picsure' AND table_name='banner_occurrence' AND constraint_name='fk_banner_occurrence_restore' AND column_name='restored_from_uuid' AND referenced_table_schema='picsure' AND referenced_table_name='banner_occurrence' AND referenced_column_name='uuid'), ':',
            (SELECT COUNT(*) FROM information_schema.key_column_usage WHERE constraint_schema='picsure' AND table_name='banner_version' AND constraint_name='fk_banner_version_occurrence' AND column_name='banner_uuid' AND referenced_table_schema='picsure' AND referenced_table_name='banner_occurrence' AND referenced_column_name='uuid'), ':',
            (SELECT COUNT(*) FROM information_schema.table_constraints WHERE table_schema='picsure' AND table_name='banner_version' AND constraint_name='uq_banner_version_number' AND constraint_type='UNIQUE'), ':',
            (SELECT GROUP_CONCAT(column_name ORDER BY ordinal_position) FROM information_schema.key_column_usage WHERE constraint_schema='picsure' AND table_name='banner_version' AND constraint_name='uq_banner_version_number'), ':',
            (SELECT LOWER(REPLACE(REPLACE(check_clause, CHAR(96), ''), ' ', '')) FROM information_schema.check_constraints WHERE constraint_schema='picsure' AND constraint_name='chk_banner_priority_allocator_singleton'), ':',
            (SELECT GROUP_CONCAT(column_name ORDER BY seq_in_index) FROM information_schema.statistics WHERE table_schema='picsure' AND table_name='banner_occurrence' AND index_name='idx_banner_occurrence_active'), ':',
            (SELECT GROUP_CONCAT(column_name ORDER BY seq_in_index) FROM information_schema.statistics WHERE table_schema='picsure' AND table_name='banner_occurrence' AND index_name='idx_banner_occurrence_priority')
        );")" \
        "1:1:1:1:1:1:banner_uuid,version_number:(id=1):status,start_at,end_at,priority:priority" \
        "banner constraints and indexes"
}

assert_authorization() {
    local pattern
    local granted_roles

    pattern="$(mysql_exec auth --execute="SELECT value FROM access_rule WHERE name = 'AR_BANNER_MANAGEMENT_GATEWAY';")"
    granted_roles="$(mysql_exec auth --execute="
        SELECT GROUP_CONCAT(r.name ORDER BY r.name SEPARATOR ',')
        FROM role r
        JOIN role_privilege rp ON rp.role_id = r.uuid
        JOIN privilege p ON p.uuid = rp.privilege_id
        WHERE p.name = 'BANNER_MANAGEMENT';")"
    assert_equal "$granted_roles" "Admin,PIC-SURE Top Admin" "banner management roles"
    assert_equal "$(mysql_exec auth --execute="
        SELECT COUNT(*) FROM role r
        JOIN role_privilege rp ON rp.role_id = r.uuid
        JOIN privilege p ON p.uuid = rp.privilege_id
        WHERE r.name = 'PIC-SURE User' AND p.name = 'BANNER_MANAGEMENT';")" \
        "0" "ordinary-user banner management denial"
    assert_equal "$(mysql_exec auth --execute="
        SELECT CONCAT(
            (SELECT COUNT(*) FROM privilege p JOIN application a ON a.uuid=p.application_id WHERE p.name='BANNER_MANAGEMENT' AND a.name='PICSURE'), ':',
            (SELECT COUNT(*) FROM accessRule_privilege arp JOIN privilege p ON p.uuid=arp.privilege_id JOIN access_rule ar ON ar.uuid=arp.accessRule_id WHERE p.name='BANNER_MANAGEMENT' AND ar.name='AR_BANNER_MANAGEMENT_GATEWAY')
        );")" "1:1" "banner management privilege ownership and access-rule link"

    python3 - "$pattern" "$repo_root/tests/banner-authorization-migration/routes.tsv" <<'PY'
import re
import sys
from pathlib import Path

pattern = sys.argv[1]
entries = [line.split("\t", 1) for line in Path(sys.argv[2]).read_text(encoding="utf-8").splitlines()]
expected = next(value for kind, value in entries if kind == "pattern")
assert pattern == expected, (pattern, expected)
rule = re.compile(pattern)
for kind, route in entries:
    if kind == "allow":
        assert rule.fullmatch(route), f"expected allowed route: {route}"
    elif kind == "deny":
        assert not rule.fullmatch(route), f"expected denied route: {route}"
PY
}

assert_final_histories() {
    assert_history auth flyway_schema_history 9 9
    assert_history picsure flyway_schema_history 8 8
    assert_history auth flyway_custom_schema_history 11 11
    assert_history picsure flyway_custom_schema_history 12 10
}

assert_final_common() {
    assert_final_histories
    assert_schema
    assert_authorization
}

run_fresh() {
    local custom_root="$tmp_root/cells/fresh"

    echo "Running AIO matrix cell: fresh"
    reset_databases
    run_core_migrations
    assert_equal "$(mysql_exec --execute="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema IN ('auth', 'picsure') AND table_name='flyway_custom_schema_history';")" \
        "0" "fresh custom migration history"
    copy_custom_set "$repo_root/Baseline" "$custom_root"
    run_custom_migrations "$custom_root"
    assert_final_common
    assert_equal "$(mysql_exec picsure --execute="SELECT CONCAT(COUNT(*), ':', MIN(next_priority), ':', MAX(next_priority)) FROM banner_priority_allocator;")" \
        "1:1:1" "fresh allocator"
    record_matrix_result fresh NONE NONE
    echo "AIO matrix cell PASS: fresh"
}

run_supported_upgrade() {
    local release_custom="$tmp_root/cells/supported-release"
    local final_custom="$tmp_root/cells/supported-final"
    local start_auth_max
    local start_picsure_max

    echo "Running AIO matrix cell: supported-upgrade"
    reset_databases
    run_core_migrations
    copy_custom_set "$source_root/migrations/Baseline" "$release_custom"
    run_custom_migrations "$release_custom"
    assert_history auth flyway_custom_schema_history 5 5
    assert_history picsure flyway_custom_schema_history 8 6
    start_auth_max="$(mysql_exec auth --execute="SELECT MAX(CAST(version AS UNSIGNED)) FROM flyway_custom_schema_history WHERE success=1;")"
    start_picsure_max="$(mysql_exec picsure --execute="SELECT MAX(CAST(version AS UNSIGNED)) FROM flyway_custom_schema_history WHERE success=1;")"
    mysql_exec < "$test_dir/supported-data.sql"
    copy_custom_set "$repo_root/Baseline" "$final_custom"
    run_custom_migrations "$final_custom"
    assert_final_common
    assert_equal "$(mysql_exec --execute="
        SELECT CONCAT(
            (SELECT COUNT(*) FROM auth.role WHERE uuid=UUID_TO_BIN('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') AND name='Synthetic preserved role'), ':',
            (SELECT COUNT(*) FROM picsure.configuration WHERE uuid=UUID_TO_BIN('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') AND name='synthetic-banner-proof' AND kind='TEST' AND value='preserve-me')
        );")" "1:1" "supported-upgrade synthetic data"
    assert_equal "$(mysql_exec picsure --execute="SELECT CONCAT(COUNT(*), ':', MIN(next_priority), ':', MAX(next_priority)) FROM banner_priority_allocator;")" \
        "1:1:1" "supported-upgrade allocator"
    record_matrix_result supported-upgrade "$start_auth_max" "$start_picsure_max"
    echo "AIO matrix cell PASS: supported-upgrade"
}

run_occurrence_only() {
    local intermediate_custom="$tmp_root/cells/occurrence-intermediate"
    local final_custom="$tmp_root/cells/occurrence-final"
    local start_auth_max
    local start_picsure_max

    echo "Running AIO matrix cell: occurrence-only"
    reset_databases
    run_core_migrations
    copy_occurrence_intermediate_set "$intermediate_custom"
    run_custom_migrations "$intermediate_custom"
    assert_history auth flyway_custom_schema_history 5 5
    assert_history picsure flyway_custom_schema_history 10 8
    start_auth_max="$(mysql_exec auth --execute="SELECT MAX(CAST(version AS UNSIGNED)) FROM flyway_custom_schema_history WHERE success=1;")"
    start_picsure_max="$(mysql_exec picsure --execute="SELECT MAX(CAST(version AS UNSIGNED)) FROM flyway_custom_schema_history WHERE success=1;")"
    mysql_exec < "$test_dir/occurrence-only.sql"
    copy_custom_set "$repo_root/Baseline" "$final_custom"
    run_custom_migrations "$final_custom"
    assert_final_common
    assert_equal "$(mysql_exec picsure --execute="
        SELECT CONCAT(
            (SELECT COUNT(*) FROM banner_version WHERE banner_uuid=UUID_TO_BIN('00000000-0000-0000-0000-000000000001') AND version_number=1 AND actor='publisher@example.org' AND effective_at='2026-08-27 12:00:00.000000'), ':',
            (SELECT COUNT(*) FROM banner_version WHERE banner_uuid=UUID_TO_BIN('00000000-0000-0000-0000-000000000002') AND version_number=1 AND actor='SYSTEM_MIGRATION' AND effective_at='2026-08-27 13:00:00.000000'), ':',
            (SELECT COUNT(*) FROM banner_version WHERE banner_uuid=UUID_TO_BIN('00000000-0000-0000-0000-000000000004') AND version_number=1 AND actor='expired-publisher@example.org' AND effective_at='2000-01-01 00:00:00.000000'), ':',
            (SELECT COUNT(*) FROM banner_version WHERE banner_uuid=UUID_TO_BIN('00000000-0000-0000-0000-000000000003')), ':',
            (SELECT COUNT(*) FROM banner_version)
        );")" "1:1:1:0:3" "occurrence version backfill"
    assert_equal "$(mysql_exec picsure --execute="
        SELECT GROUP_CONCAT(CONCAT(BIN_TO_UUID(uuid), '=', priority) ORDER BY priority SEPARATOR ',')
        FROM banner_occurrence;")" \
        "00000000-0000-0000-0000-000000000001=4,00000000-0000-0000-0000-000000000002=40,00000000-0000-0000-0000-000000000004=80,00000000-0000-0000-0000-000000000003=90" \
        "occurrence priorities"
    assert_equal "$(mysql_exec picsure --execute="SELECT CONCAT(COUNT(*), ':', MIN(next_priority), ':', MAX(next_priority)) FROM banner_priority_allocator;")" \
        "1:41:41" "occurrence allocator"
    record_matrix_result occurrence-only "$start_auth_max" "$start_picsure_max"
    echo "AIO matrix cell PASS: occurrence-only"
}

prepare_sources
verify_release_overlap
verify_checksum_manifest "$test_dir/feature-sql.sha256"
verify_checksum_manifest "$test_dir/occurrence-intermediate-sql.sha256"
verify_matrix_contract
start_mysql

case "$cell" in
    fresh) run_fresh ;;
    supported-upgrade) run_supported_upgrade ;;
    occurrence-only) run_occurrence_only ;;
    all)
        run_fresh
        run_supported_upgrade
        run_occurrence_only
        "$repo_root/tests/banner-authorization-migration/test.sh"
        "$repo_root/tests/banner-version-migration/test.sh" \
            "$repo_root/Baseline/picsure/V10__CREATE_BANNER_OCCURRENCE.sql" \
            "$repo_root/Baseline/picsure/V11__CREATE_BANNER_VERSION.sql" \
            "$repo_root/Baseline/picsure/V12__CREATE_BANNER_PRIORITY_ALLOCATOR.sql"
        ;;
esac

verify_matrix_results
echo "AIO deployment-owned banner migration proof PASS: $cell"
