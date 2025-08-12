-- 0xF65B425F867044061ACE73A1BF7F4402 - PIC_SURE_ANY_QUERY

INSERT INTO `role` (`name`, `description`) VALUES
('MANUAL_ROLE_OPEN_ACCESS', 'Role for users with open access to PIC-SURE data');

INSERT INTO `role_privilege` (`role_id`, `privilege_id`) VALUES
((SELECT `uuid` FROM `role` WHERE `name` = 'MANUAL_ROLE_OPEN_ACCESS'),
 (SELECT `uuid` FROM `privilege` WHERE `name` = 'PIC_SURE_ANY_QUERY'));