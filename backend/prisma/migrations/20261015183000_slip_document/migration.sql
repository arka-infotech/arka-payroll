ALTER TABLE "monthly_payroll" ADD COLUMN IF NOT EXISTS "pay_date" DATE;
ALTER TABLE "monthly_payroll" ADD COLUMN IF NOT EXISTS "slip_document" JSONB;
