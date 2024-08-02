use auth;

SET @uuidRule = REPLACE(UUID(), '-', '');
INSERT
    INTO access_rule (
        uuid, name, description, value,
        rule, type, checkMapKeyOnly, checkMapNode, subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
    )
    VALUES (
        unhex(@uuidRule), 'SAVE_DATASET', 'Can only do /dataset', '/dataset/named',
        ' $.[\'Target Service\']', 6, 0, 0, NULL, 0, 0
    );

SET @uuidPriv = REPLACE(UUID(), '-', '');
INSERT
    INTO privilege (
        uuid, name,
        description,
        application_id
    )
    VALUES (
        unhex(@uuidPriv), 'SAVE_DATASET',
        'Allow access to the /dataset/named/ function',
        (SELECT uuid FROM application WHERE name = 'PICSURE')
    );

INSERT
    INTO accessRule_privilege ( privilege_id, accessRule_id )
    VALUES ( unhex(@uuidPriv), unhex(@uuidRule) );

INSERT
    INTO role_privilege ( role_id, privilege_id )
    VALUES ( (SELECT uuid FROM role WHERE name = 'PIC-SURE User'), unhex(@uuidPriv) );
