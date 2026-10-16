-- Flexible / in-hand packages are valid; percentage rules are enforced in app when flex_breakup is false.
ALTER TABLE "salary_structures" DROP CONSTRAINT IF EXISTS "salary_structures_basic_pct_chk";
ALTER TABLE "salary_structures" DROP CONSTRAINT IF EXISTS "salary_structures_hra_pct_chk";
