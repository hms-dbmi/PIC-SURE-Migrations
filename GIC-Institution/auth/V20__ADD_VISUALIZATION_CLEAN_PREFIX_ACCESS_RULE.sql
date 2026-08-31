-- Additive gateway clean-prefix rule for visualization; legacy /proxy path kept until WildFly is decommissioned.

SET @allVizCleanPrefixRequests = unhex(REPLACE(UUID(),'-',''));
-- Access rule for allowing requests to visualization via the gateway clean-prefix path
INSERT
INTO access_rule (
    uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
    subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
)    VALUES (
                @allVizCleanPrefixRequests, 'ALLOW_VISUALIZATION_CLEAN_PREFIX', 'Permit requests to visualization endpoints',
                '$.[\'Target Service\']', 11, '^/visualization(/.*)?$', 0x00, 0x00, NULL, 0x00, 0x00
            );
-- Add that access rule to the PIC_SURE_ANY_QUERY privilege
SET @uuidPriv = (SELECT uuid FROM privilege WHERE name = 'PIC_SURE_ANY_QUERY');
INSERT
INTO accessRule_privilege (privilege_id, accessRule_id)
VALUES
    (@uuidPriv, @allVizCleanPrefixRequests);
