-- Rollout requirement: PSAMA caches merged access rules per user and application in `mergedRulesCache` and
-- `preProcessedAccessRules`, so on an existing install the new privilege attachment is not visible to
-- already-cached sessions. Restart the PSAMA instances or evict both caches after this migration runs.
use auth;

INSERT INTO access_rule (
    uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
    subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
)
SELECT
    UNHEX(REPLACE('5c92234d-e3e1-428c-8c4c-eba6b725d53a', '-', '')),
    'AR_AI_SERVICE_REQUESTS',
    'Permit requests to the AI-Service endpoint',
    '$.[\'Target Service\']', 11, '^/ai(/.*)?$',
    0x00, 0x00, NULL, 0x00, 0x00
WHERE NOT EXISTS (SELECT 1 FROM access_rule WHERE name = 'AR_AI_SERVICE_REQUESTS');

INSERT INTO privilege (uuid, name, description, application_id, queryScope)
SELECT
    UNHEX(REPLACE('d9aaa1b4-0115-45f3-b594-70ff9d7da702', '-', '')),
    'PIC_SURE_AI_SERVICE',
    'Allow access to the AI-Service endpoint',
    (SELECT uuid FROM application WHERE name = 'PICSURE'),
    '[]'
WHERE NOT EXISTS (SELECT 1 FROM privilege WHERE name = 'PIC_SURE_AI_SERVICE');

SET @aisPrivilege = (SELECT uuid FROM privilege WHERE name = 'PIC_SURE_AI_SERVICE');

INSERT INTO accessRule_privilege (privilege_id, accessRule_id)
SELECT @aisPrivilege, access_rule.uuid
FROM access_rule
WHERE access_rule.name = 'AR_AI_SERVICE_REQUESTS'
AND NOT EXISTS (
    SELECT 1
    FROM accessRule_privilege existing
    WHERE existing.privilege_id = @aisPrivilege
      AND existing.accessRule_id = access_rule.uuid
);

INSERT INTO role_privilege (role_id, privilege_id)
SELECT role.uuid, @aisPrivilege
FROM role
WHERE role.name IN ('MANUAL_ROLE_OPEN_ACCESS', 'PIC-SURE User', 'Admin', 'PIC-SURE Top Admin')
AND NOT EXISTS (
    SELECT 1
    FROM role_privilege existing
    WHERE existing.role_id = role.uuid
      AND existing.privilege_id = @aisPrivilege
);
