use auth;

INSERT
    INTO access_rule (
        uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
        subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
    )    VALUES (
        unhex(REPLACE(uuid(),'-','')), 'Secret Dataframe', 'Dataframes that cannot be accessed',
        '$..expectedResultType', 4, 'SECRET_ADMIN_DATAFRAME', 0x00, 0x00, NULL, 0x00, 0x00
    );

-- We alias the access rule table as 'ar' in the insert query because MYSQL doesn't let you reference the table you are
-- inserting into directly.
-- This regex is essentially matching to three cases:
--  /query
--  /query/<uuid>/sync
--  /query/<uuid>/status
INSERT
    INTO access_rule (
        uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
        subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
    )
    VALUES (
        unhex(REPLACE(uuid(),'-','')), 'Secret Dataframe Query Route Regex', 'Dataframes that cannot be accessed',
        '$.[\'Target Service\']', 11, '((/query.*/(sync|status))|(/query))$', 0x00, 0x00,
        (SELECT ar.uuid FROM access_rule as ar WHERE ar.name = 'Secret Dataframe'), 0x00, 0x00
    );


INSERT
    INTO privilege (uuid, name, description, application_id)
    VALUES (
        unhex(REPLACE(uuid(),'-','')), 'SECRET_ADMIN_DATAFRAME', 'Un-viewable dataframe privilege for PICSURE application',
        (SELECT uuid FROM application WHERE name = 'PICSURE')
    );

INSERT
    INTO accessRule_privilege (privilege_id, accessRule_id)
	VALUES (
		(SELECT uuid FROM privilege WHERE name = 'SECRET_ADMIN_DATAFRAME'),
		(SELECT uuid FROM access_rule WHERE name = 'Secret Dataframe')
	);
	
INSERT
    INTO role (uuid, name, description)
	VALUES (unhex(REPLACE(uuid(),'-','')),
		'PIC-SURE Secret Dataframe Requester',
		'PIC-SURE Secret Dataframe Requester.  Can create dataframes, but cannot view them.'
	);

INSERT
    INTO role_privilege (role_id, privilege_id)
    VALUES (
        (SELECT uuid FROM role WHERE name = 'PIC-SURE Secret Dataframe Requester'),
        (SELECT uuid FROM privilege WHERE name = 'SECRET_ADMIN_DATAFRAME')
    );