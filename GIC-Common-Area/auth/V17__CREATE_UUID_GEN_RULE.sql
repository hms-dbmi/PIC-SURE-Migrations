use auth;

set @resourceUUID = (SELECT
  LOWER(CONCAT(
    SUBSTR(HEX(uuid), 1, 8), '-',
    SUBSTR(HEX(uuid), 9, 4), '-',
    SUBSTR(HEX(uuid), 13, 4), '-',
    SUBSTR(HEX(uuid), 17, 4), '-',
    SUBSTR(HEX(uuid), 21)
  )) from picsure.resource where name = "Query-ID-Gen");

SET @uuidRule = REPLACE(UUID(),'-','');
INSERT
    INTO access_rule (
        uuid, name, description, rule, type, value, checkMapKeyOnly, checkMapNode,
        subAccessRuleParent_uuid, isGateAnyRelation, isEvaluateOnlyByGates
    )    VALUES (
        unhex(@uuidRule), 'CREATE_UUID', 'Create common area UUID', '$query.resourceUUID', 4,
        @resourceUUID, 0x00, 0x00, NULL, 0x00, 0x00
    );

SET @uuidPriv = REPLACE(UUID(),'-','');
INSERT
    INTO privilege (uuid, name, description, application_id)
    VALUES (
        unhex(@uuidPriv), 'CREATE_UUID', 'Create common area UUID',
        (SELECT uuid FROM application WHERE name = 'PICSURE')
    );

INSERT INTO accessRule_privilege (privilege_id, accessRule_id)
     VALUES (
          unhex(@uuidPriv),
          unhex(@uuidRule)
     );

SET @uuidRole = (SELECT uuid FROM role WHERE name = 'PIC-SURE User');
INSERT INTO role_privilege (role_id, privilege_id) VALUES (@uuidRole, unhex(@uuidPriv));

