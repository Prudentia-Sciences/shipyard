-- Optional run matcher for service_environments: when multiple environments
-- point to the same workflow file, strategy + value differentiate which runs
-- count for which environment (e.g. branch 'main' -> production, 'develop' -> staging).
-- workflow_file remains required; matcher is an extension only.

ALTER TABLE service_environments
  ADD COLUMN run_match_strategy TEXT,
  ADD COLUMN run_match_value TEXT;

-- Strategy: 'any' or NULL = latest successful run (current behavior);
-- 'branch' = filter by head branch; 'event' = filter by trigger event.
-- Restrict strategy to known values.
ALTER TABLE service_environments
  ADD CONSTRAINT service_environments_run_match_strategy_check
  CHECK (run_match_strategy IS NULL OR run_match_strategy IN ('any', 'branch', 'event'));

-- When strategy is branch or event, run_match_value must be non-empty.
ALTER TABLE service_environments
  ADD CONSTRAINT service_environments_run_match_value_required
  CHECK (
    run_match_strategy IS NULL
    OR run_match_strategy = 'any'
    OR (run_match_value IS NOT NULL AND trim(run_match_value) <> '')
  );

COMMENT ON COLUMN service_environments.run_match_strategy IS 'Optional: any, branch, or event. When set with run_match_value, filters workflow runs for this environment.';
COMMENT ON COLUMN service_environments.run_match_value IS 'Value for run_match_strategy (e.g. branch name or event name). Required when strategy is branch or event.';
