INSERT INTO `privilege` (
    uuid,
    description,
    name,
    application_id,
    queryScope,
    queryTemplate
) VALUES (
    0xFD5513B5C5814867AADC3CD7E87C31D2,
    'User who can manage saved datasets',
    'NAMED_DATASET',
    (SELECT uuid FROM application WHERE name = 'PICSURE'),
    '[]',
    NULL
);

INSERT INTO `privilege` (
    uuid,
    description,
    name,
    application_id,
    queryScope,
    queryTemplate
) VALUES (
    0x2CEC38E28895494B9FA8D1FE9737C387,
    'User who can access the Ananlyze pages',
    'API_ACCESS',
    (SELECT uuid FROM application WHERE name = 'PICSURE'),
    '[]',
    NULL
);

INSERT INTO `role_privilege` (role_id, privilege_id) VALUES 
(0x797FD002DC366B0D8420F998F885D0ED,0xFD5513B5C5814867AADC3CD7E87C31D2),
(0x797FD002DC366B0D8420F998F885D0ED,0x2CEC38E28895494B9FA8D1FE9737C387);
