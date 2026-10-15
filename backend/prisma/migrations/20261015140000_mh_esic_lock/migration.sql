-- Maharashtra startup payroll: ESIC column + default EPF off + lock support

ALTER TABLE "salary_structures"
  ADD COLUMN IF NOT EXISTS "esic_applicable" BOOLEAN NOT NULL DEFAULT false;

-- Startup default: EPF optional until headcount crosses threshold
ALTER TABLE "salary_structures"
  ALTER COLUMN "epf_applicable" SET DEFAULT false;

ALTER TABLE "monthly_payroll"
  ADD COLUMN IF NOT EXISTS "esic_employee" DECIMAL(12,2) NOT NULL DEFAULT 0;
