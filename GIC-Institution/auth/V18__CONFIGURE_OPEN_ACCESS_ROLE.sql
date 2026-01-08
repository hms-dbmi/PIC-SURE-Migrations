
SET @uuidRole := REPLACE(UUID(), '-', '');
INSERT INTO `role` (`uuid`, `name`, `description`) VALUES
(unhex(@uuidRole), 'MANUAL_ROLE_OPEN_ACCESS', 'Role for users with open access to PIC-SURE data');

INSERT INTO `role_privilege` (`role_id`, `privilege_id`) VALUES
((SELECT `uuid` FROM `role` WHERE `name` = 'MANUAL_ROLE_OPEN_ACCESS'),
 (SELECT `uuid` FROM `privilege` WHERE `name` = 'PIC_SURE_ANY_QUERY'));
