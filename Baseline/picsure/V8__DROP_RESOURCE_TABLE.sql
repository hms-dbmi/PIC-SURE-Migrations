use picsure;

-- Gateway rewrite (Phase 7): routing moved to the gateway's static per-service routes and the
-- resource registry endpoints were removed, so the resource table is unused. Drop the
-- query -> resource foreign key (the resourceId column stays for historical rows) and then the
-- table itself. Baseline flavor only for now -- the GIC flavors keep the table until the
-- passthrough-service migration decision (Add Site to Passthrough Service writes to it).
-- The FK name is looked up dynamically so this also works on older databases where the
-- constraint was created by Hibernate with a different generated name.
SET @fk := (SELECT CONSTRAINT_NAME FROM information_schema.REFERENTIAL_CONSTRAINTS
            WHERE CONSTRAINT_SCHEMA = 'picsure'
              AND TABLE_NAME = 'query'
              AND REFERENCED_TABLE_NAME = 'resource'
            LIMIT 1);
SET @stmt := IF(@fk IS NULL, 'SELECT 1', CONCAT('ALTER TABLE `query` DROP FOREIGN KEY `', @fk, '`'));
PREPARE drop_fk FROM @stmt;
EXECUTE drop_fk;
DEALLOCATE PREPARE drop_fk;

DROP TABLE IF EXISTS `resource`;
