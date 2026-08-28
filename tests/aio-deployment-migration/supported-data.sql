INSERT INTO auth.role (uuid, name, description)
VALUES (
    UUID_TO_BIN('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    'Synthetic preserved role',
    'Synthetic AIO migration proof row'
);

INSERT INTO picsure.configuration (uuid, name, kind, value, description, markForDelete)
VALUES (
    UUID_TO_BIN('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    'synthetic-banner-proof',
    'TEST',
    'preserve-me',
    'Synthetic AIO migration proof row',
    FALSE
);
