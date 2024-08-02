
SET @uuidGate = REPLACE(UUID(),'-','');
INSERT INTO access_rule VALUES (
    unhex(@uuidGate),
    'GATE_RESOURCE',
    'triggers rules for resource endpoint',
    ' $.[\'Target Service\']',
    6,
    '/resource',
    0,
    0,
    NULL,
    0,
    0
  );

  SET @uuidRule = REPLACE(UUID(),'-','');
  INSERT INTO access_rule VALUES (
    unhex(@uuidRule),
    'AR_RESOURCE_LIST',
    'Can list /resources',
    ' $.[\'query\']',
    13,
    NULL,
    0,
    0,
    NULL,
    0,
    0
  );
  
INSERT INTO accessRule_gate (accessRule_id, gate_id)
       VALUES (unhex(@uuidRule), unhex(@uuidGate));
  
       
SET @uuidPriv = REPLACE(UUID(),'-','');
INSERT INTO privilege (uuid, name, description, application_id)
     VALUES ( unhex(@uuidPriv),
          'PRIV_LIST_RESOURCES',
          'Allow access to the /resource/ endpoint',
          (SELECT uuid FROM application WHERE name = 'PICSURE')
     );

INSERT INTO accessRule_privilege (privilege_id, accessRule_id)
     VALUES (
          unhex(@uuidPriv),
          unhex(@uuidRule)
     );
     

-- several privileges weren't being evaulated.  since we need to restrict access to resource endpoint 
-- we need to fix these up
INSERT INTO role_privilege (role_id, privilege_id)
     values ( (select uuid from role where name = 'PIC-SURE User'), 
     unhex(@uuidPriv) );
     
INSERT INTO role_privilege (role_id, privilege_id)
     values ( (select uuid from role where name = 'PIC-SURE User'), 
       (select uuid from privilege where name = 'PRIV_INFO_COLUMN_LISTING') );  
     
INSERT INTO role_privilege (role_id, privilege_id)
     values ( (select uuid from role where name = 'PIC-SURE User'), 
       (select uuid from privilege where name = 'PRIV_ONLY_SEARCH') );  

      
 -- We need to fill out the aggregate rules to include cross count queries
INSERT INTO access_rule (uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode, subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates)
     VALUES (unhex(REPLACE(uuid(),'-','')), 'HPDS Cross Counts', 'HPDS cross Counts', '$..expectedResultType', 4, 'CROSS_COUNT', 0x00, 0x00, NULL, 0x00, 0x00);
      
INSERT INTO accessRule_privilege (privilege_id, accessRule_id)
     VALUES (
          (SELECT uuid FROM privilege WHERE name = 'AGGREGATE'),
          (SELECT uuid FROM access_rule WHERE name = 'HPDS Cross Counts')
     );
       
INSERT INTO role_privilege (role_id, privilege_id)
     values ( (select uuid from role where name = 'PIC-SURE User'), 
       (select uuid from privilege where name = 'AGGREGATE') );  
     
       

      
-- now add rules for the data managers to allow updates to their resource

-- BCH --
set @resourceUUID = (SELECT
  LOWER(CONCAT(
    SUBSTR(HEX(uuid), 1, 8), '-',
    SUBSTR(HEX(uuid), 9, 4), '-',
    SUBSTR(HEX(uuid), 13, 4), '-',
    SUBSTR(HEX(uuid), 17, 4), '-',
    SUBSTR(HEX(uuid), 21)
  )) from picsure.resource where name = "BCH");
  
SET @uuidRule = REPLACE(UUID(),'-','');
INSERT INTO access_rule VALUES (
    unhex(@uuidRule),
    'AR_UPDATE_BCH_RESOURCE',
    'allow update to BCH resource',
    '$..uuid',
    4,
    @resourceUUID,
    0,
    0,
    NULL,
    0,
    0
  );
       
SET @uuidPriv = REPLACE(UUID(),'-','');
INSERT INTO privilege (uuid, name, description, application_id)
     VALUES ( unhex(@uuidPriv),
          'PRIV_DATA_MANAGER_BCH',
          'Allow updates to the /resource/ endpoint for BCH resource',
          (SELECT uuid FROM application WHERE name = 'PICSURE')
     );
     
INSERT INTO accessRule_privilege (privilege_id, accessRule_id)
     VALUES (
          unhex(@uuidPriv),
          unhex(@uuidRule)
     );
     
SET @uuidRole = REPLACE(UUID(),'-','');
  INSERT INTO role VALUES ( 
      unhex(@uuidRole), 
     'DATA_MANAGER_BCH', 
     'Allow Updates of BCH resource metadata' 
  );

INSERT INTO role_privilege (role_id, privilege_id)
	VALUES (
		unhex(@uuidRole),
		unhex(@uuidPriv)
	);

	
-- CHOP --
set @resourceUUID = (SELECT
  LOWER(CONCAT(
    SUBSTR(HEX(uuid), 1, 8), '-',
    SUBSTR(HEX(uuid), 9, 4), '-',
    SUBSTR(HEX(uuid), 13, 4), '-',
    SUBSTR(HEX(uuid), 17, 4), '-',
    SUBSTR(HEX(uuid), 21)
  )) from picsure.resource where name = "CHOP");
  
SET @uuidRule = REPLACE(UUID(),'-','');
INSERT INTO access_rule VALUES (
    unhex(@uuidRule),
    'AR_UPDATE_CHOP_RESOURCE',
    'allow update to CHOP resource',
    '$..uuid',
    4,
    @resourceUUID,
    0,
    0,
    NULL,
    0,
    0
  );
       
SET @uuidPriv = REPLACE(UUID(),'-','');
INSERT INTO privilege (uuid, name, description, application_id)
     VALUES ( unhex(@uuidPriv),
          'PRIV_DATA_MANAGER_CHOP',
          'Allow updates to the /resource/ endpoint for CHOP resource',
          (SELECT uuid FROM application WHERE name = 'PICSURE')
     );
     
INSERT INTO accessRule_privilege (privilege_id, accessRule_id)
     VALUES (
          unhex(@uuidPriv),
          unhex(@uuidRule)
     );
     
SET @uuidRole = REPLACE(UUID(),'-','');
  INSERT INTO role VALUES ( 
      unhex(@uuidRole), 
     'DATA_MANAGER_CHOP', 
     'Allow Updates of CHOP resource metadata' 
  );

INSERT INTO role_privilege (role_id, privilege_id)
	VALUES (
		unhex(@uuidRole),
		unhex(@uuidPriv)
	);
	
	
-- CCHMC --
set @resourceUUID = (SELECT
  LOWER(CONCAT(
    SUBSTR(HEX(uuid), 1, 8), '-',
    SUBSTR(HEX(uuid), 9, 4), '-',
    SUBSTR(HEX(uuid), 13, 4), '-',
    SUBSTR(HEX(uuid), 17, 4), '-',
    SUBSTR(HEX(uuid), 21)
  )) from picsure.resource where name = "CCHMC");
  
SET @uuidRule = REPLACE(UUID(),'-','');
INSERT INTO access_rule VALUES (
    unhex(@uuidRule),
    'AR_UPDATE_CCHMC_RESOURCE',
    'allow update to CCHMC resource',
    '$..uuid',
    4,
    @resourceUUID,
    0,
    0,
    NULL,
    0,
    0
  );
       
SET @uuidPriv = REPLACE(UUID(),'-','');
INSERT INTO privilege (uuid, name, description, application_id)
     VALUES ( unhex(@uuidPriv),
          'PRIV_DATA_MANAGER_CCHMC',
          'Allow updates to the /resource/ endpoint for CCHMC resource',
          (SELECT uuid FROM application WHERE name = 'PICSURE')
     );
     
INSERT INTO accessRule_privilege (privilege_id, accessRule_id)
     VALUES (
          unhex(@uuidPriv),
          unhex(@uuidRule)
     );
     
SET @uuidRole = REPLACE(UUID(),'-','');
  INSERT INTO role VALUES ( 
      unhex(@uuidRole), 
     'DATA_MANAGER_CCHMC', 
     'Allow Updates of CCHMC resource metadata' 
  );

INSERT INTO role_privilege (role_id, privilege_id)
	VALUES (
		unhex(@uuidRole),
		unhex(@uuidPriv)
	);

	
	
-- WASHU --
set @resourceUUID = (SELECT
  LOWER(CONCAT(
    SUBSTR(HEX(uuid), 1, 8), '-',
    SUBSTR(HEX(uuid), 9, 4), '-',
    SUBSTR(HEX(uuid), 13, 4), '-',
    SUBSTR(HEX(uuid), 17, 4), '-',
    SUBSTR(HEX(uuid), 21)
  )) from picsure.resource where name = "WASHU");
  
SET @uuidRule = REPLACE(UUID(),'-','');
INSERT INTO access_rule VALUES (
    unhex(@uuidRule),
    'AR_UPDATE_WASHU_RESOURCE',
    'allow update to WASHU resource',
    '$..uuid',
    4,
    @resourceUUID,
    0,
    0,
    NULL,
    0,
    0
  );
       
SET @uuidPriv = REPLACE(UUID(),'-','');
INSERT INTO privilege (uuid, name, description, application_id)
     VALUES ( unhex(@uuidPriv),
          'PRIV_DATA_MANAGER_WASHU',
          'Allow updates to the /resource/ endpoint for WASHU resource',
          (SELECT uuid FROM application WHERE name = 'PICSURE')
     );
     
INSERT INTO accessRule_privilege (privilege_id, accessRule_id)
     VALUES (
          unhex(@uuidPriv),
          unhex(@uuidRule)
     );
     
SET @uuidRole = REPLACE(UUID(),'-','');
  INSERT INTO role VALUES ( 
      unhex(@uuidRole), 
     'DATA_MANAGER_WASHU', 
     'Allow Updates of WASHU resource metadata' 
  );

INSERT INTO role_privilege (role_id, privilege_id)
	VALUES (
		unhex(@uuidRole),
		unhex(@uuidPriv)
	);