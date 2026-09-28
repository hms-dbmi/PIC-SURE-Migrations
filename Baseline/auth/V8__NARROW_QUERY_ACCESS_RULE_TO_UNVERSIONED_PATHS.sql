-- Narrow AR_QUERY_REQUESTS to the unversioned HPDS query paths.
--
-- Rollout requirement: run this only after the pic-sure release that stops serving
-- /hpds/{backend}/v3/query... is deployed to the environment. Until then the frontend and
-- API clients may still send the /v3 form, and this rule is the only Baseline rule that
-- grants it, so running early denies every query from those clients with a 403.
--
-- The update matches the exact value V6 seeded. An environment whose rule was edited by
-- hand keeps its value and needs a manual review instead.
--
-- PSAMA caches merged access rules in `mergedRulesCache` and `preProcessedAccessRules`.
-- Sessions cached before this runs keep the wider pattern until the PSAMA instances restart
-- or both caches are evicted. The wider pattern only matches paths the query service no
-- longer serves, so the delay is harmless.
use auth;

UPDATE access_rule
SET value = '^/hpds/(auth|open)/query(/.*)?$'
WHERE name = 'AR_QUERY_REQUESTS'
  AND type = 11
  AND value = '^/hpds/(auth|open)(/v3)?/query(/.*)?$';
