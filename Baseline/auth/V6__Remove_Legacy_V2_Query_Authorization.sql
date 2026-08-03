-- ALS-12479 - remove legacy v2 query authorization from the auth schema.
--
-- ============================ HOLD UNTIL CUTOVER =============================
-- DO NOT APPLY THIS MIGRATION BEFORE THE WILDFLY CUTOVER (ALS-11782).
-- A WildFly PSAMA still authorizes v2 queries from exactly the rows this file
-- deletes. The Spring PSAMA on the ALS-12479 branch no longer generates any of
-- them, so they are inert under v3, but they must not be removed while WildFly
-- serves traffic.
--
-- NOTHING IN THIS REPOSITORY ENFORCES THAT HOLD. The only thing that does is
-- the build spec. The AIO "PIC-SURE Database Migrations" Jenkins job checks out
-- this repository at psm_ref, INDEPENDENTLY of psa_ref (the PSAMA/monorepo ref).
-- Advancing psm_ref without advancing psa_ref applies this file against a
-- pre-ALS-12479 PSAMA and causes exactly the failure described below. The two
-- refs must advance together.
--
-- The same applies to a FRESH AIO INSTALL: the project-specific pass runs with
-- -baselineOnMigrate=true, so V2 through V6 all apply in one go during initial
-- configuration, and this file drops the columns that
-- V4__ADD_DATASET_AND_API_PRIVS.sql wrote seconds earlier. That is only safe if
-- the PSAMA image being installed alongside is post-ALS-12479.
-- ============================================================================
--
-- ==================== THE CODE DEPLOY IS MANDATORY FIRST =====================
-- This is not tidy sequencing. Running this migration against a pre-ALS-12479
-- PSAMA is TOTAL AUTHORIZATION FAILURE, not a warning in the log:
--
--   * Privilege.java maps queryTemplate and queryScope as ordinary persistent
--     fields (no @Transient) at the pre-branch commit, and
--     spring.jpa.hibernate.ddl-auto is commented out, so Hibernate never
--     validates the schema at boot. Section 5 drops both columns. The old build
--     starts cleanly and then fails with "Unknown column 'queryTemplate'" on
--     EVERY privilege load - which is every authorization decision.
--   * Separately, AR_INFO_COLUMN_LISTING is deleted here and was removed from
--     the fence.standard.access.rules property on the ALS-12479 branch. An
--     older build logs "Unable to find an access rule with name
--     AR_INFO_COLUMN_LISTING" on every boot. That one is only noise.
--
-- Deploy the ALS-12479 build first. Then run this.
-- ============================================================================
--
-- AIO ships no v2 access rules in SQL, but PSAMA generated them at runtime from
-- the FENCE mapping, so these rows exist in AIO databases. Same cleanup applies.
--
-- SCOPE
--   This file is a Baseline migration (flyway_custom_schema_history). It runs
--   after the core auth schema migrations in
--   pic-sure/services/pic-sure-auth-microapp/pic-sure-auth-db/db/sql, which is
--   where queryScope and queryTemplate are added (core V3). GIC-Common-Area and
--   GIC-Institution are separate Flyway locations and do not run this file;
--   they keep the columns and any legacy rows until an equivalent migration is
--   added there.
--
-- ==================== RUN THIS PRE-FLIGHT QUERY FIRST ========================
-- Read-only. It reports the one condition that blocks this migration: a
-- surviving privilege that this file would strip down to zero access rules.
-- Section 2 aborts the migration if any exist, but you want to know before you
-- start, not from a failed deploy.
--
--   use auth;
--
--   CREATE TEMPORARY TABLE legacy_v2_rules (uuid binary(16) NOT NULL PRIMARY KEY);
--   INSERT INTO legacy_v2_rules (uuid)
--   SELECT uuid FROM access_rule
--    WHERE name LIKE 'AR\_CONSENT\_%'
--       OR name LIKE 'AR\_TOPMED\_%'
--       OR name LIKE 'AR\_PHENO\_%'
--       OR name IN (
--            'GATE_PARENT_CONSENT_PRESENT',      'GATE_PARENT_CONSENT_MISSING',
--            'GATE_HARMONIZED_CONSENT_PRESENT',  'GATE_HARMONIZED_CONSENT_MISSING',
--            'GATE_TOPMED_CONSENT_PRESENT',      'GATE_TOPMED_CONSENT_MISSING',
--            'AR_INFO_COLUMN_LISTING',           'GATE_DONOT_ALLOW_INFO_COLUMN_LISTING',
--            'AR_ALLOW_COUNT',                   'AR_ALLOW_CROSS_COUNT',
--            'AR_ALLOW_CATEGORICAL_CROSS_COUNT', 'AR_ALLOW_CONTINUOUS_CROSS_COUNT',
--            'AR_ALLOW_DATAFRAME',               'AR_ALLOW_DATAFRAME_PFB'
--          )
--       OR (name LIKE 'AR\_ALLOW\_%' AND rule = '$.query.query.expectedResultType');
--
--   SELECT p.name AS privilege_name,
--          (SELECT COUNT(*) FROM accessRule_privilege arp
--            WHERE arp.privilege_id = p.uuid) AS rules_now,
--          (SELECT COUNT(DISTINCT ur.user_id)
--             FROM role_privilege rp
--             JOIN user_role ur ON ur.role_id = rp.role_id
--            WHERE rp.privilege_id = p.uuid) AS users_attached
--     FROM privilege p
--    WHERE p.name NOT LIKE 'PRIV\_MANAGED\_%'
--      AND EXISTS (SELECT 1 FROM accessRule_privilege arp
--                   WHERE arp.privilege_id = p.uuid)
--      AND NOT EXISTS (SELECT 1 FROM accessRule_privilege arp
--                       WHERE arp.privilege_id = p.uuid
--                         AND arp.accessRule_id NOT IN (SELECT uuid FROM legacy_v2_rules));
--
--   DROP TEMPORARY TABLE legacy_v2_rules;
--
-- A NON-EMPTY RESULT BLOCKS THIS MIGRATION. Each listed privilege must be
-- deleted, or re-attached to a surviving rule, before this file may run. Do not
-- work around the section 2 guard. See "WHY AN EMPTIED PRIVILEGE IS FATAL".
-- ============================================================================
--
-- WHY AN EMPTIED PRIVILEGE IS FATAL
--   AuthorizationService (~183-189) returns EvaluateAccessRuleResult(true, ...)
--   and logs "NO ACCESS RULES EVALUATED" when a user's privileges resolve to an
--   empty rule set. An access-rule-less privilege is an UNCONDITIONAL GRANT, not
--   a denial. AccessRuleService.cachedPreProcessAccessRules unions the rules of
--   all of a user's privileges, so the grant fires for any user whose whole
--   privilege set has been emptied.
--
--   The deletes below remove accessRule_privilege rows BY RULE, with no regard
--   for what the owning privilege is left holding. The residual vector is a
--   privilege composed in the admin UI out of v2 rules only: nothing constrains
--   an admin-built privilege to hold a rule this migration keeps, and such a
--   privilege is not in the delete set, so it survives with an empty rule list.
--   AIO is more exposed than BDC here, because AIO ships no access rules in SQL
--   at all - every rule attachment in an AIO auth database was made at runtime
--   or through the admin UI.
--
--   Note what is NOT the vector, because it is an easy and dangerous thing to
--   assume: FENCE-generated PRIVILEGES were named PRIV_FENCE_<study>, which
--   core V6__UPDATE_EXISTING_ROLE_PRIVILEGE_RULE_NAMES.sql's FENCE_* -> MANAGED_*
--   rename maps to PRIV_MANAGED_<study>. Those DO match the delete predicate and
--   are removed outright, not emptied. MANAGED_<study>_<consent> is a generated
--   ROLE name (FENCE_<projectId>_<consentCode> before the rename); no code path
--   ever produced a privilege by that name.
--
--   Section 2 aborts the migration if any such privilege exists.
--
-- WHY RULE NAMES ARE ENUMERATED AND NEVER PREFIX-MATCHED ON AR_ALLOW_%
--   'AR_ALLOW_%' also covers every open-access grant in a PIC-SURE auth schema:
--   AR_ALLOW_OPEN_ACCESS, AR_ALLOW_OPEN_ACCESS_V3,
--   AR_ALLOW_OPEN_ACCESS_V3_GATEWAY, AR_ALLOW_DICTIONARY_ACCESS and
--   AR_ALLOW_STAT_VIS. All of those authorize by resource
--   (rule = '$.query.resourceUUID') or by path (rule = '$.[''Target Service'']')
--   and must survive. The v2 rules are therefore named literally, plus one sweep
--   scoped by rule text (rule = '$.query.query.expectedResultType') to catch
--   per-environment FENCE_ALLOWED_QUERY_TYPES overrides that produced
--   AR_ALLOW_<queryType> names absent from the literal list. No open-access
--   grant uses that rule text, so the sweep cannot reach one.
--
-- WHAT SURVIVES
--   CAVEAT: Baseline/auth ships NO access rules at all, so the rule names below
--   are the ones a PIC-SURE auth database is expected to hold, not ones this
--   repository can be grepped to confirm. They come from the BDC migration set
--   and from PSAMA's runtime behaviour. Treat this list as aspirational and
--   verify against the target database with the pre-flight query above.
--
--   Every endpoint-shaped rule (AR_ONLY_INFO, AR_ONLY_SEARCH, AR_NO_SEARCH,
--   GATE_SEARCH, AR_NO_QUERY_ACCESS, GATE_QUERY, AR_NAMED_DATASET,
--   AR_DICTIONARY_REQUESTS, AR_LOGGING_REQUESTS, the AR_*_CLEAN_PREFIX rules)
--   and the type-17 consent gates GATE_QUERY_v3, GATE_QUERY_HPDS_AUTH_V3 and
--   GATE_QUERY_HPDS_OPEN_V3, which are the live v3 authorization path. Also
--   AR_METADATA_ACCESS - in BDC it ships in V3 as ALLOW_METADATA_ACCESS and is
--   only renamed by V7, so the earlier name may be what an older database holds.
--   Everything Baseline ships survives: roles PIC-SURE Top Admin, Admin,
--   PIC-SURE User, JupyterHub User and MANUAL_ROLE_OPEN_ACCESS; privileges
--   SUPER_ADMIN, ADMIN, PIC_SURE_ANY_QUERY, JUPYTER_USER, NAMED_DATASET and
--   API_ACCESS. None of those match the deleted patterns.
--   Only PRIV_MANAGED_% privileges are deleted - note that is a different
--   string from the MANAGED_PRIV_* privileges, which survive.
--
-- WHY THE MANAGED_ ROLE DELETE IS GUARDED
--   The core migration V6__UPDATE_EXISTING_ROLE_PRIVILEGE_RULE_NAMES.sql renames
--   every FENCE_* role, privilege and rule to MANAGED_*. Unlike BDC (whose V7
--   renames MANAGED_ROLE_OPEN_ACCESS to MANUAL_ROLE_OPEN_ACCESS), AIO has no
--   such follow-up, so an older AIO database can legitimately hold a MANAGED_
--   role that is not a dbGaP-permission marker. A MANAGED_ role is therefore
--   only removed when every privilege it holds is itself being removed.
--
-- GATE DETACHMENT
--   Deleting a rule forces removal of its accessRule_gate rows. Gates are
--   conjunctive: a surviving rule that loses a gate becomes easier to pass. The
--   only shipped gate deleted here is GATE_DONOT_ALLOW_INFO_COLUMN_LISTING,
--   whose rule text ($.query.query.expectedResultType) does not exist in a v3
--   request body, so any surviving rule it gates is already failing under v3.
--
-- ATOMICITY
--   Sections 1-4 are DML and roll back together if the section 2 guard fires.
--   CREATE/DROP TEMPORARY TABLE does not force an implicit commit, so the temp
--   tables do not break that. Section 5 is DDL: each ALTER TABLE forces an
--   implicit commit, so the file is NOT atomic across the two column drops. If
--   the second drop fails, queryTemplate is gone and queryScope remains; re-run
--   the file, which is idempotent, rather than restoring.

use auth;

-- ---------------------------------------------------------------------------
-- 1. Collect every row this migration removes, before deleting anything.
--    The role set must be computed before the privileges are deleted: it is
--    defined in terms of the privileges a role still holds.
-- ---------------------------------------------------------------------------

DROP TEMPORARY TABLE IF EXISTS `legacy_v2_rules`;
CREATE TEMPORARY TABLE `legacy_v2_rules` (`uuid` binary(16) NOT NULL PRIMARY KEY);

INSERT INTO `legacy_v2_rules` (`uuid`)
SELECT `uuid`
  FROM `access_rule`
 WHERE `name` LIKE 'AR\_CONSENT\_%'      -- AR_CONSENT_<phs>[_<consent>]_<label>
    OR `name` LIKE 'AR\_TOPMED\_%'       -- AR_TOPMED_* and AR_TOPMED_RESTRICTED_*
    OR `name` LIKE 'AR\_PHENO\_%'        -- AR_PHENO_<alias>_<label> sub-rules
    OR `name` IN (
         'GATE_PARENT_CONSENT_PRESENT',      'GATE_PARENT_CONSENT_MISSING',
         'GATE_HARMONIZED_CONSENT_PRESENT',  'GATE_HARMONIZED_CONSENT_MISSING',
         'GATE_TOPMED_CONSENT_PRESENT',      'GATE_TOPMED_CONSENT_MISSING',
         'AR_INFO_COLUMN_LISTING',           'GATE_DONOT_ALLOW_INFO_COLUMN_LISTING',
         'AR_ALLOW_COUNT',                   'AR_ALLOW_CROSS_COUNT',
         'AR_ALLOW_CATEGORICAL_CROSS_COUNT', 'AR_ALLOW_CONTINUOUS_CROSS_COUNT',
         'AR_ALLOW_DATAFRAME',               'AR_ALLOW_DATAFRAME_PFB'
       )
    -- Per-environment FENCE_ALLOWED_QUERY_TYPES overrides. Scoped by rule text
    -- so no open-access grant can match; see the header.
    OR (`name` LIKE 'AR\_ALLOW\_%' AND `rule` = '$.query.query.expectedResultType');

DROP TEMPORARY TABLE IF EXISTS `legacy_v2_privileges`;
CREATE TEMPORARY TABLE `legacy_v2_privileges` (`uuid` binary(16) NOT NULL PRIMARY KEY);

-- PRIV_MANAGED_<study>[_<consent>][_HARMONIZED|_TOPMED], generated per study.
-- PSAMA no longer creates these. MANAGED_PRIV_* is a different prefix and is
-- deliberately not matched.
INSERT INTO `legacy_v2_privileges` (`uuid`)
SELECT `uuid` FROM `privilege` WHERE `name` LIKE 'PRIV\_MANAGED\_%';

DROP TEMPORARY TABLE IF EXISTS `legacy_v2_roles`;
CREATE TEMPORARY TABLE `legacy_v2_roles` (`uuid` binary(16) NOT NULL PRIMARY KEY);

-- MANAGED_<phsId>[_<consentGroup>] dbGaP-permission markers, superseded by
-- user_consents. Guarded as described in the header.
INSERT INTO `legacy_v2_roles` (`uuid`)
SELECT r.`uuid`
  FROM `role` r
 WHERE r.`name` LIKE 'MANAGED\_%'
   AND NOT EXISTS (
         SELECT 1
           FROM `role_privilege` rp
           JOIN `privilege` p ON p.`uuid` = rp.`privilege_id`
          WHERE rp.`role_id` = r.`uuid`
            AND p.`name` NOT LIKE 'PRIV\_MANAGED\_%'
       );

-- ---------------------------------------------------------------------------
-- 2. ABORT GUARD: refuse to run if any surviving privilege would be left with
--    zero access rules. An emptied privilege is an unconditional grant; see
--    "WHY AN EMPTIED PRIVILEGE IS FATAL" in the header.
--
--    Scoped to privileges this migration would empty - those that hold at least
--    one rule now and none afterwards. Privileges that are ALREADY rule-less are
--    deliberately not flagged: that is a pre-existing condition this file did
--    not create, and blocking on it would make the migration un-runnable for a
--    reason outside its scope.
-- ---------------------------------------------------------------------------

DROP TEMPORARY TABLE IF EXISTS `emptied_privileges`;
CREATE TEMPORARY TABLE `emptied_privileges` (`uuid` binary(16) NOT NULL PRIMARY KEY);

INSERT INTO `emptied_privileges` (`uuid`)
SELECT p.`uuid`
  FROM `privilege` p
 WHERE p.`uuid` NOT IN (SELECT `uuid` FROM `legacy_v2_privileges`)
   AND EXISTS (
         SELECT 1 FROM `accessRule_privilege` arp WHERE arp.`privilege_id` = p.`uuid`
       )
   AND NOT EXISTS (
         SELECT 1
           FROM `accessRule_privilege` arp
          WHERE arp.`privilege_id` = p.`uuid`
            AND arp.`accessRule_id` NOT IN (SELECT `uuid` FROM `legacy_v2_rules`)
       );

-- Fail loudly if any were found. Signal by violating the primary key
-- constraint — duplicate of the offending privilege's own uuid — which errors
-- 1062 in every sql_mode, strict or not (error aborts the migration; on failure
-- run the pre-flight query in the header to list the privileges, then delete or
-- re-attach them with George before re-running — sections 1-4 are DML,
-- nothing half-applies). Same pattern as BDC V19's MIGRATION_GUARD insert.
INSERT INTO `privilege` (`uuid`, `name`, `description`, `application_id`)
SELECT p.`uuid`, 'MIGRATION_GUARD_EMPTIED_PRIVILEGE',
       'MIGRATION GUARD: privilege would be left with zero access rules — manual review required',
       NULL
FROM `privilege` p
JOIN `emptied_privileges` e ON e.`uuid` = p.`uuid`
LIMIT 1;

DROP TEMPORARY TABLE `emptied_privileges`;

-- ---------------------------------------------------------------------------
-- 3. Detach referencing rows first so the deletes below are FK-safe.
--    access_rule.uuid is referenced by accessRule_gate (both columns),
--    accessRule_subRule (both columns), accessRule_privilege.accessRule_id and
--    access_rule.subAccessRuleParent_uuid.
--    privilege.uuid is referenced by accessRule_privilege and role_privilege.
--    role.uuid is referenced by role_privilege and user_role.
-- ---------------------------------------------------------------------------

-- subAccessRuleParent_uuid is a legacy self-FK that the AccessRule entity no
-- longer maps. Core V5__MIGRATE_TO_ACCESSRULE_JOINTABLE.sql moved its contents
-- into accessRule_subRule and nulled it, but never dropped the column, so the
-- constraint still exists. Null any surviving reference into the delete set.
UPDATE `access_rule`
   SET `subAccessRuleParent_uuid` = NULL
 WHERE `subAccessRuleParent_uuid` IN (SELECT `uuid` FROM `legacy_v2_rules`);

DELETE ag FROM `accessRule_gate` ag JOIN `legacy_v2_rules` l ON ag.`accessRule_id` = l.`uuid`;
DELETE ag FROM `accessRule_gate` ag JOIN `legacy_v2_rules` l ON ag.`gate_id`       = l.`uuid`;

DELETE asr FROM `accessRule_subRule` asr JOIN `legacy_v2_rules` l ON asr.`accessRule_id` = l.`uuid`;
DELETE asr FROM `accessRule_subRule` asr JOIN `legacy_v2_rules` l ON asr.`subRule_id`    = l.`uuid`;

DELETE arp FROM `accessRule_privilege` arp JOIN `legacy_v2_rules`      l ON arp.`accessRule_id` = l.`uuid`;
DELETE arp FROM `accessRule_privilege` arp JOIN `legacy_v2_privileges` l ON arp.`privilege_id`  = l.`uuid`;

DELETE rp FROM `role_privilege` rp JOIN `legacy_v2_privileges` l ON rp.`privilege_id` = l.`uuid`;
DELETE rp FROM `role_privilege` rp JOIN `legacy_v2_roles`      l ON rp.`role_id`      = l.`uuid`;

DELETE ur FROM `user_role` ur JOIN `legacy_v2_roles` l ON ur.`role_id` = l.`uuid`;

-- ---------------------------------------------------------------------------
-- 4. Delete the rows themselves.
-- ---------------------------------------------------------------------------

DELETE ar FROM `access_rule` ar JOIN `legacy_v2_rules`      l ON ar.`uuid` = l.`uuid`;
DELETE p  FROM `privilege`   p  JOIN `legacy_v2_privileges` l ON p.`uuid`  = l.`uuid`;
DELETE r  FROM `role`        r  JOIN `legacy_v2_roles`      l ON r.`uuid`  = l.`uuid`;

DROP TEMPORARY TABLE `legacy_v2_rules`;
DROP TEMPORARY TABLE `legacy_v2_privileges`;
DROP TEMPORARY TABLE `legacy_v2_roles`;

-- ---------------------------------------------------------------------------
-- 5. Drop the v2 query-shape columns.
--    queryTemplate and queryScope described the v2 query body. PSAMA stopped
--    mapping them in ALS-12479 and ddl-auto is unset, so it has been ignoring
--    them. Core V3__ADD_COLUMNS_PRIVILEGE_TABLE.sql adds both as
--    VARCHAR(8192) with no NOT NULL, so both are nullable and the drop cannot
--    fail on existing data. Baseline V4__ADD_DATASET_AND_API_PRIVS.sql writes
--    them, and runs before this file in the same Flyway location.
--    Guarded on information_schema so the file stays re-runnable; MySQL has no
--    ALTER TABLE ... DROP COLUMN IF EXISTS.
--
--    CAVEAT: PREPARE/EXECUTE has no precedent in Baseline, GIC-Common-Area,
--    GIC-Institution or the BDC migration set, and the AIO runner is a pinned
--    image (dbmi/pic-sure-db-migrations:pic-sure-db-migration_v1.0) whose Flyway
--    version is not recorded here. Flyway splits on semicolons outside string
--    literals and none of these statements contain one, so it should be handled
--    like any other statement - but dry-run this file against a scratch copy of
--    an auth database at cutover before running it anywhere real. If the runner
--    rejects it, replace both blocks with a bare
--    "ALTER TABLE `privilege` DROP COLUMN `queryTemplate`, DROP COLUMN `queryScope`;"
--    and accept the loss of re-runnability.
-- ---------------------------------------------------------------------------

SET @dropQueryTemplate := (
    SELECT IF(COUNT(*) > 0, 'ALTER TABLE `privilege` DROP COLUMN `queryTemplate`', 'DO 0')
      FROM `information_schema`.`COLUMNS`
     WHERE `TABLE_SCHEMA` = DATABASE()
       AND `TABLE_NAME`   = 'privilege'
       AND `COLUMN_NAME`  = 'queryTemplate'
);
PREPARE dropQueryTemplateStmt FROM @dropQueryTemplate;
EXECUTE dropQueryTemplateStmt;
DEALLOCATE PREPARE dropQueryTemplateStmt;

SET @dropQueryScope := (
    SELECT IF(COUNT(*) > 0, 'ALTER TABLE `privilege` DROP COLUMN `queryScope`', 'DO 0')
      FROM `information_schema`.`COLUMNS`
     WHERE `TABLE_SCHEMA` = DATABASE()
       AND `TABLE_NAME`   = 'privilege'
       AND `COLUMN_NAME`  = 'queryScope'
);
PREPARE dropQueryScopeStmt FROM @dropQueryScope;
EXECUTE dropQueryScopeStmt;
DEALLOCATE PREPARE dropQueryScopeStmt;
