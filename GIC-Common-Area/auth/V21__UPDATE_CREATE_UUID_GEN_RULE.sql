use auth;

UPDATE access_rule SET rule = "query.resourceUUID" WHERE name = "CREATE_UUID";
