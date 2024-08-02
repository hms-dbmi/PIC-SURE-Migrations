use auth;

DELETE
    FROM `userMetadataMapping`
    WHERE uuid = unhex('B6BD9D7F9E3311ECA5F4126ACB86EEFB');

INSERT
    INTO `userMetadataMapping` (uuid, auth0MetadataJsonPath, connectionId, generalMetadataJsonPath)
    VALUES (unhex('2B464334D120880E2250A7626FC2ED8D'), '$.email', unhex('B6BD9D7F9E3311ECA5F4126ACB86EEFB'), '$.email');
