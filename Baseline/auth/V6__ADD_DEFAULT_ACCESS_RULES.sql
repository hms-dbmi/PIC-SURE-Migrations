-- Preserve Baseline's historical open-access behavior with explicit rules.
--
-- PSAMA now denies requests when a user's privileges resolve to no access
-- rules. Baseline users receive PIC_SURE_ANY_QUERY through the default
-- PIC-SURE User role, so attach one rule for each protected gateway function
-- instead of relying on the former empty-rule fail-open behavior.
--
-- The first four names are PSAMA's configured standard access rules. Keeping
-- those names also lets PSAMA attach the common info, search, dictionary, and
-- logging routes to other privileges during startup, matching the existing
-- BDC authorization model.

INSERT INTO access_rule (
    uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
    subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
)
SELECT
    UNHEX(REPLACE('7d8b87c9-6796-4b4b-b147-5a759b9f4878', '-', '')),
    'AR_ONLY_INFO',
    'Permit requests to info endpoints',
    '$.[\'Target Service\']', 6, '/info',
    0x00, 0x00, NULL, 0x00, 0x00
WHERE NOT EXISTS (SELECT 1 FROM access_rule WHERE name = 'AR_ONLY_INFO');

INSERT INTO access_rule (
    uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
    subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
)
SELECT
    UNHEX(REPLACE('624a5b11-9acf-4d97-8cfb-bb1c5d855cd0', '-', '')),
    'AR_ONLY_SEARCH',
    'Permit requests to search endpoints',
    '$.[\'Target Service\']', 6, '/search',
    0x00, 0x00, NULL, 0x00, 0x00
WHERE NOT EXISTS (SELECT 1 FROM access_rule WHERE name = 'AR_ONLY_SEARCH');

INSERT INTO access_rule (
    uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
    subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
)
SELECT
    UNHEX(REPLACE('516ef443-3c6d-4bc9-8aa9-edb7bd853404', '-', '')),
    'AR_DICTIONARY_REQUESTS',
    'Permit requests to dictionary endpoints',
    '$.[\'Target Service\']', 11, '^/dictionary(/.*)?$',
    0x00, 0x00, NULL, 0x00, 0x00
WHERE NOT EXISTS (SELECT 1 FROM access_rule WHERE name = 'AR_DICTIONARY_REQUESTS');

INSERT INTO access_rule (
    uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
    subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
)
SELECT
    UNHEX(REPLACE('d72360b3-3120-49dd-ba1e-676f9f2cb5df', '-', '')),
    'AR_LOGGING_REQUESTS',
    'Permit requests to logging endpoints',
    '$.[\'Target Service\']', 11, '^/logging(/.*)?$',
    0x00, 0x00, NULL, 0x00, 0x00
WHERE NOT EXISTS (SELECT 1 FROM access_rule WHERE name = 'AR_LOGGING_REQUESTS');

INSERT INTO access_rule (
    uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
    subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
)
SELECT
    UNHEX(REPLACE('ef707f24-2a1d-4ae9-881d-8184e53e6a34', '-', '')),
    'AR_QUERY_REQUESTS',
    'Permit authenticated and open HPDS query lifecycle requests',
    '$.[\'Target Service\']', 11, '^/hpds/(auth|open)(/v3)?/query(/.*)?$',
    0x00, 0x00, NULL, 0x00, 0x00
WHERE NOT EXISTS (SELECT 1 FROM access_rule WHERE name = 'AR_QUERY_REQUESTS');

INSERT INTO access_rule (
    uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
    subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
)
SELECT
    UNHEX(REPLACE('15881e37-5561-426f-8fa9-02b30500b7d1', '-', '')),
    'AR_VISUALIZATION_REQUESTS',
    'Permit requests to visualization endpoints',
    '$.[\'Target Service\']', 11, '^/visualization(/.*)?$',
    0x00, 0x00, NULL, 0x00, 0x00
WHERE NOT EXISTS (SELECT 1 FROM access_rule WHERE name = 'AR_VISUALIZATION_REQUESTS');

INSERT INTO access_rule (
    uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
    subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
)
SELECT
    UNHEX(REPLACE('131931ff-00cc-47a6-baca-60d4d99a0480', '-', '')),
    'AR_OPERATIONS_CONFIGURATION_REQUESTS',
    'Permit requests to operations configuration endpoints',
    '$.[\'Target Service\']', 11, '^/operations/configuration(/.*)?$',
    0x00, 0x00, NULL, 0x00, 0x00
WHERE NOT EXISTS (SELECT 1 FROM access_rule WHERE name = 'AR_OPERATIONS_CONFIGURATION_REQUESTS');

INSERT INTO access_rule (
    uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
    subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
)
SELECT
    UNHEX(REPLACE('ef4d97d6-afa7-49ad-9fb8-703cd3da47eb', '-', '')),
    'AR_NAMED_DATASET_GATEWAY',
    'Permit requests to named dataset endpoints',
    '$.[\'Target Service\']', 11,
    '^/operations/dataset/named(/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}))?$',
    0x00, 0x00, NULL, 0x00, 0x00
WHERE NOT EXISTS (SELECT 1 FROM access_rule WHERE name = 'AR_NAMED_DATASET_GATEWAY');

SET @picSureAnyQuery = (SELECT uuid FROM privilege WHERE name = 'PIC_SURE_ANY_QUERY');

INSERT INTO accessRule_privilege (privilege_id, accessRule_id)
SELECT @picSureAnyQuery, access_rule.uuid
FROM access_rule
WHERE access_rule.name IN (
    'AR_ONLY_INFO',
    'AR_ONLY_SEARCH',
    'AR_DICTIONARY_REQUESTS',
    'AR_LOGGING_REQUESTS',
    'AR_QUERY_REQUESTS',
    'AR_VISUALIZATION_REQUESTS',
    'AR_OPERATIONS_CONFIGURATION_REQUESTS',
    'AR_NAMED_DATASET_GATEWAY'
)
AND NOT EXISTS (
    SELECT 1
    FROM accessRule_privilege existing
    WHERE existing.privilege_id = @picSureAnyQuery
      AND existing.accessRule_id = access_rule.uuid
);
