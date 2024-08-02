use auth;

-- Casing issue: id was lower case. Stuff wasn't matching.
UPDATE `connection`
    SET id = 'WUSTL'
    WHERE label = 'WUSTL';
