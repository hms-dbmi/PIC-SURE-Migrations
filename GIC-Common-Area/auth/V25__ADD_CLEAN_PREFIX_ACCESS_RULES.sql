-- Phase 3: additive gateway clean-prefix rules; legacy /proxy rules retained until Phase 7 (WildFly decommission).
--
-- Note: this environment (GIC-Common-Area) only has a legacy access rule for the dictionary
-- proxy path (V23__ADD_DICTIONARY_ACCESS_RULE.sql, linked to PIC_SURE_ANY_QUERY). There is no
-- legacy uploader access rule or DATA_ADMIN-style privilege wired up in this set, so there is
-- nothing to mirror for an uploader clean-prefix rule here. Only the dictionary clean-prefix
-- rule is added in this migration.

SET @allDictCleanPrefixRequests = unhex(REPLACE(UUID(),'-',''));
-- Access rule for allowing requests to the dictionary via the gateway clean-prefix path
INSERT
INTO access_rule (
    uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
    subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
)    VALUES (
                @allDictCleanPrefixRequests, 'ALLOW_DICTIONARY_CLEAN_PREFIX', 'Permit requests to dictionary endpoints',
                '$.[\'Target Service\']', 11, '^/dictionary(/.*)?$', 0x00, 0x00, NULL, 0x00, 0x00
            );
-- Add that access rule to the DATA_ADMIN privilege
SET @uuidPriv = (SELECT uuid FROM privilege WHERE name = 'PIC_SURE_ANY_QUERY');
INSERT
INTO accessRule_privilege (privilege_id, accessRule_id)
VALUES
    (@uuidPriv, @allDictCleanPrefixRequests);
