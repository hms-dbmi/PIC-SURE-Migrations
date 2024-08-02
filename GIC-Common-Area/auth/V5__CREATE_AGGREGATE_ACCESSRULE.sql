use auth;

INSERT INTO access_rule (uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode, subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates)
	VALUES (unhex(REPLACE(uuid(),'-','')), 'HPDS Aggregate Counts', 'HPDS Counts', '$..expectedResultType', 4, 'COUNT', 0x00, 0x00, NULL, 0x00, 0x00);

INSERT INTO access_rule (uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode, subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates)
	VALUES (unhex(REPLACE(uuid(),'-','')), 'HPDS Aggregate Observation Counts', 'HPDS observation Counts', '$..expectedResultType', 4, 'OBSERVATION_COUNT', 0x00, 0x00, NULL, 0x00, 0x00);

INSERT INTO access_rule (uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode, subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates)
	VALUES (unhex(REPLACE(uuid(),'-','')), 'HPDS Aggregate Observation Cross Counts', 'HPDS observation cross Counts', '$..expectedResultType', 4, 'OBSERVATION_CROSS_COUNT', 0x00, 0x00, NULL, 0x00, 0x00);
	
	
INSERT INTO privilege (uuid, name, description, application_id)
	VALUES (unhex(REPLACE(uuid(),'-','')),
		'AGGREGATE',
		'Aggregiate Data Sharing privilege for PICSURE application',
		(SELECT uuid FROM application WHERE name = 'PICSURE')
	);

INSERT INTO accessRule_privilege (privilege_id, accessRule_id)
	VALUES (
		(SELECT uuid FROM privilege WHERE name = 'AGGREGATE'),
		(SELECT uuid FROM access_rule WHERE name = 'HPDS Aggregate Counts')
	);
	
INSERT INTO accessRule_privilege (privilege_id, accessRule_id)
	VALUES (
		(SELECT uuid FROM privilege WHERE name = 'AGGREGATE'),
		(SELECT uuid FROM access_rule WHERE name = 'HPDS Aggregate Observation Counts')
	);
	
INSERT INTO accessRule_privilege (privilege_id, accessRule_id)
	VALUES (
		(SELECT uuid FROM privilege WHERE name = 'AGGREGATE'),
		(SELECT uuid FROM access_rule WHERE name = 'HPDS Aggregate Observation Cross Counts')
	);
	
	
INSERT INTO role (uuid, name, description)
	VALUES (unhex(REPLACE(uuid(),'-','')),
		'PIC-SURE Aggregate Count User',
		'PIC-SURE Aggregate Count User.  Can perform aggregate count queries only.'
	);

INSERT INTO role_privilege (role_id, privilege_id)
	VALUES (
		(SELECT uuid FROM role WHERE name = 'PIC-SURE Aggregate Count User'),
		(SELECT uuid FROM privilege WHERE name = 'AGGREGATE')
	);