
SET @uuidADFSConn = UNHEX(REPLACE(UUID(),'-',''));
SET @uuidLDAPConn = (select uuid from connection where id='ldap-connector');

-- Create the connection entity for BCH-ADFS
INSERT INTO `connection` VALUES (@uuidADFSConn, 'BCH-ADFS', 'BCH-ADFS','adfs|BCH-ADFS|','[{"label":"BCH Email", "id":"email"}]');

-- Create the userMetadataMapping for BCH-ADFS
INSERT INTO `userMetadataMapping` VALUES 
(UNHEX(REPLACE(uuid(), '-', '')), '$.email', @uuidADFSConn, '$.email');

-- Create an ADFS user for each of the ldap-connector users. 
-- We preserve the ability to roll back to the ldap-connector if necessary and also preserve the UUIDs for audit purposes
 insert into user 
   (select UNHEX(REPLACE(uuid(), '-', '')), NULL, general_metadata, acceptedTOS, @uuidADFSConn, email,0x00,NULL, is_active, NULL
    from user where connectionId=@uuidLDAPConn);

-- Assign the same roles to the ADFS users that are assigned to the LDAP users

insert into user_role (select b.uuid new_uuid, role_id from 
	(select * from user_role left join user on user_id=uuid where connectionId=@uuidLDAPConn)  a
	left join 
	(select * from user where connectionId=@uuidADFSConn) b on a.email = b.email );

