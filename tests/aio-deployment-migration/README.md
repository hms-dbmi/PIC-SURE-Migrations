# AIO deployment migration proof

`test.sh` follows the AIO database job order against disposable MySQL 8. It runs the release-pinned core authorization and PIC-SURE migrations, substitutes the deployment UUID placeholders in a temporary custom migration copy, and runs the real Baseline PIC-SURE and authorization directories with `flyway_custom_schema_history`.

The three result rows in `matrix.tsv` use this vocabulary:

- `PASS`: the sequence completed and all schema, history, data, allocator, and route assertions passed.
- `FAIL`: at least one sequence or assertion failed. No checked-in row may use this value.
- `MATCH`: every banner feature SQL file matches `feature-sql.sha256`.
- `MISMATCH`: at least one banner feature SQL file differs. No checked-in row may use this value.

The harness tests with `flyway/flyway:11.7.2`. The AIO job invokes `dbmi/pic-sure-db-migrations:pic-sure-db-migration_v1.0`, but the repository does not declare that image's embedded Flyway version. This proof therefore covers the SQL sequence and separate history-table behavior, not deployment-engine or Jenkins runtime parity. The later PostgreSQL dictionary stage is not exercised because it does not use the `auth` or `picsure` schemas.

Run all cells and the existing focused migration checks:

```bash
tests/aio-deployment-migration/test.sh all
```

Pass `fresh`, `supported-upgrade`, or `occurrence-only` to run one matrix cell. For offline repetition, set `AIO_PROOF_SOURCE_ROOT` to a directory containing exact detached checkouts named `release-control`, `psama`, `psa`, and `migrations`. The script verifies every checkout SHA before using it.
