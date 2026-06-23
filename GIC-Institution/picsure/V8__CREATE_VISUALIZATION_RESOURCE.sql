use picsure;

-- Register the standalone visualization service as a PIC-SURE resource.
--
-- The frontend reaches it through the API proxy endpoint (/proxy/visualization/...),
-- and ProxyWebClient rejects any container whose name is not a registered resource row
-- ("container name not trustworthy"). The proxy keys on resource.name only, so the name
-- 'visualization' is what matters here; the UUID is generated and owned by this migration
-- so it works on existing deployments too (which never re-run the install scripts).

-- Remove the legacy in-WildFly visualization resource registered by the old
-- "Create PIC-SURE Visualization Build" job (removed from all-in-one in 4e10748).
-- That job registered a WAR deployed inside WildFly, e.g.
-- http://wildfly:8080/pic-sure-visualization-resource/pic-sure/visualization/ ;
-- it is replaced by the standalone container below.
DELETE FROM `resource`
 WHERE resourceRSPath LIKE 'http://wildfly:%/pic-sure/visualization/';

-- Find-or-create the standalone visualization resource. If a 'visualization' resource
-- already exists (e.g. from a re-run), keep it and refresh its fields; otherwise create
-- one with a generated UUID. This makes the migration idempotent without relying on any
-- externally supplied UUID.
UPDATE `resource`
   SET targetURL      = NULL,
       resourceRSPath = 'http://visualization/',
       description    = 'Visualization',
       token          = NULL,
       hidden         = TRUE,
       metadata       = NULL
 WHERE name = 'visualization';

INSERT INTO `resource`
    (uuid, targetURL, resourceRSPath, description, name, token, hidden, metadata)
SELECT unhex(REPLACE(UUID(), '-', '')), NULL, 'http://visualization/', 'Visualization', 'visualization', NULL, TRUE, NULL
WHERE NOT EXISTS (SELECT 1 FROM `resource` WHERE name = 'visualization');
