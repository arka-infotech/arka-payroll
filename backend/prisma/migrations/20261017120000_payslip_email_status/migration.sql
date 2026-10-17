-- Track payslip email outcome after lock (no Chrome required for sending).
ALTER TABLE "monthly_payroll"
  ADD COLUMN IF NOT EXISTS "email_status" VARCHAR(16),
  ADD COLUMN IF NOT EXISTS "email_sent_at" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "email_error" VARCHAR(500);
