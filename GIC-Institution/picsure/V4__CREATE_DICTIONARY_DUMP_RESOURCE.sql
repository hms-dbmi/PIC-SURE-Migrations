SET @dictResourceUUID = unhex(REPLACE(UUID(), '-', ''));

INSERT INTO `resource`
(uuid, targetURL, resourceRSPath, description, name, token, hidden, metadata)
VALUES
    (@dictResourceUUID, NULL, 'http://dictionary-dump/',
     'Dictionary Dump', 'dictionary-dump', NULL, TRUE, NULL);