INSERT INTO picsure.banner_occurrence (
    uuid, status, html_content, title, appearance, icon, dismissible, audience, placement, page_targets,
    start_at, end_at, priority, presentation_hash, created_at, created_by, updated_at, updated_by,
    published_at, published_by
) VALUES (
    UUID_TO_BIN('00000000-0000-0000-0000-000000000001'),
    'PUBLISHED', '<p>Published actor and time</p>', 'Published metadata', 'WARNING', 'WARNING', FALSE,
    'SIGNED_IN', 'SITE_TOP', JSON_ARRAY(JSON_OBJECT('kind', 'ALL')),
    '2026-08-27 11:30:00.000000', '2099-08-28 12:00:00.000000', 4, REPEAT('a', 64),
    '2026-08-27 10:00:00.000000', 'creator@example.org', '2026-08-27 13:00:00.000000',
    'updater@example.org', '2026-08-27 12:00:00.000000', 'publisher@example.org'
), (
    UUID_TO_BIN('00000000-0000-0000-0000-000000000002'),
    'PUBLISHED', '<p>Updated time fallback</p>', 'Fallback metadata', 'PRIMARY', 'INFORMATION', TRUE,
    'EVERYONE', 'SITE_TOP', JSON_ARRAY(JSON_OBJECT('kind', 'EXACT', 'path', '/help')),
    '2026-08-27 13:00:00.000000', NULL, 40, REPEAT('b', 64),
    '2026-08-27 10:00:00.000000', 'creator@example.org', '2026-08-27 13:00:00.000000',
    'updater@example.org', NULL, ''
), (
    UUID_TO_BIN('00000000-0000-0000-0000-000000000003'),
    'SAVED', '<p>Saved banner</p>', 'Saved metadata', 'ERROR', 'NONE', TRUE,
    'SIGNED_OUT', 'SITE_TOP', JSON_ARRAY(JSON_OBJECT('kind', 'ALL')),
    NULL, NULL, 9, REPEAT('c', 64),
    '2026-08-27 09:00:00.000000', 'creator@example.org', '2026-08-27 09:00:00.000000',
    'creator@example.org', NULL, NULL
);
