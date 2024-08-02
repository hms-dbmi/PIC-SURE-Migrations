use auth;

UPDATE access_rule
    SET rule = '$.[\'Target Service\']'
    WHERE name IN ('SAVE_DATASET', 'AR_ONLY_SEARCH', 'AR_ONLY_resource', 'AR_ONLY_info/resource', 'GATE_RESOURCE');

UPDATE access_rule
    SET rule = '$.[\'query\']'
    WHERE name IN ('AR_RESOURCE_LIST');
