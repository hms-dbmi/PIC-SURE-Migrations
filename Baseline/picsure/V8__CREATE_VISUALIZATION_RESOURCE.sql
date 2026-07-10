use picsure;

-- Register the standalone visualization service as a PIC-SURE resource.
--
-- The frontend reaches it through the API proxy endpoint (/proxy/visualization/...),
-- and ProxyWebClient rejects any container whose name is not a registered resource row
-- ("container name not trustworthy"). The proxy keys on resource.name only, so the name
-- 'visualization' is what matters here; the UUID is either inherited from the repurposed
-- legacy row or generated fresh below, so nothing external may depend on its value.

-- Find-or-repurpose: one UPDATE covers both rows a deployment might already have.
--  * The legacy in-WildFly resource registered by the old "Create PIC-SURE Visualization
--    Build" job (removed from all-in-one with the standalone visualization rollout,
--    ALS-11990), matched by its path, e.g.
--    http://wildfly:8080/pic-sure-visualization-resource/pic-sure/visualization/ .
--    It is renamed in place rather than deleted: query.resourceId references
--    resource.uuid with no ON DELETE action, so environments where the legacy resource
--    was ever queried (the pre-proxy frontend sent visualizations through /query/sync,
--    which persists a query row per request) have query rows pointing at it, and a
--    DELETE would fail the migration with a foreign key error.
--  * A row already named 'visualization' (pre-created by hand, or left by a previous
--    run of this migration), whose fields are simply refreshed.
-- Note: resource.name has no unique index, so a site with both a legacy row and a
-- pre-created 'visualization' row ends up with two rows of the same name; the proxy
-- uses whichever row its name lookup returns. Both rows get identical values here,
-- so behavior is the same either way.
UPDATE `resource`
   SET name           = 'visualization',
       targetURL      = NULL,
       resourceRSPath = 'http://visualization/',
       description    = 'Visualization',
       token          = NULL,
       hidden         = TRUE,
       metadata       = NULL
 WHERE resourceRSPath LIKE 'http://wildfly:%/pic-sure/visualization/'
    OR name = 'visualization';

-- Fresh install: nothing matched above, so create the row with a generated UUID.
INSERT INTO `resource`
    (uuid, targetURL, resourceRSPath, description, name, token, hidden, metadata)
SELECT unhex(REPLACE(UUID(), '-', '')), NULL, 'http://visualization/', 'Visualization', 'visualization', NULL, TRUE, NULL
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM `resource` WHERE name = 'visualization');
