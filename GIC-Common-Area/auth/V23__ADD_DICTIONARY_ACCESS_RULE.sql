SET @allDictRequests = unhex(REPLACE(UUID(),'-',''));
-- Access rule for allowing requests to the dictionary via proxy
INSERT
INTO access_rule (
    uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
    subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
)    VALUES (
                @allDictRequests, 'ALLOW_DICTIONARY', 'Permit requests to dictionary endpoints',
                '$.[\'Target Service\']', 11, '^/proxy/dictionary-api/.*$', 0x00, 0x00, NULL, 0x00, 0x00
            );
-- Add that access rule to the DATA_ADMIN privilege
SET @uuidPriv = (SELECT uuid FROM privilege WHERE name = 'PIC_SURE_ANY_QUERY');
INSERT
INTO accessRule_privilege (privilege_id, accessRule_id)
VALUES
    (@uuidPriv, @allDictRequests);