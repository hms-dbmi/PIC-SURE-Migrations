-- Additive gateway clean-prefix rules; legacy /proxy rules retained until WildFly is decommissioned.

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

SET @allowUploaderCleanPrefixRequests = unhex(REPLACE(UUID(),'-',''));
-- Access rule for allowing requests to the uploader via the gateway clean-prefix path
INSERT
    INTO access_rule (
        uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
        subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
    )    VALUES (
        @allowUploaderCleanPrefixRequests, 'ALLOW_UPLOADER_CLEAN_PREFIX', 'Permit requests to uploader endpoints',
        '$.[\'Target Service\']', 11, '^/uploader(/.*)?$', 0x00, 0x00, NULL, 0x00, 0x00
    );
-- Add that access rule to the DATA_ADMIN privilege
SET @uuidPriv = (SELECT uuid FROM privilege WHERE name = 'DATA_ADMIN');
INSERT
    INTO accessRule_privilege (privilege_id, accessRule_id)
	VALUES
	    (@uuidPriv, @allowUploaderCleanPrefixRequests);
