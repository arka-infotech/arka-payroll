ALTER TABLE "salary_structures" ADD COLUMN IF NOT EXISTS "flex_breakup" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "salary_structures" ADD COLUMN IF NOT EXISTS "professional_tax_applicable" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "salary_structures" ADD COLUMN IF NOT EXISTS "tds_applicable" BOOLEAN NOT NULL DEFAULT false;
