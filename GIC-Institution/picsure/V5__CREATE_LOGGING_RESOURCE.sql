use picsure;
INSERT INTO `resource`
    (uuid, targetURL, resourceRSPath, description, name, token, hidden, metadata)
    VALUES
    (unhex(REPLACE('35d190ad-6547-46c5-a7ad-ae35cfd2e34b', '-', '')), NULL,
     'http://pic-sure-logging:8080/', 'Logging Service', 'logging', NULL, TRUE, NULL);
