-- Remove legacy 2-slot HR Admin cap
DROP TRIGGER IF EXISTS trg_hr_admin_slot_limit ON users;
DROP FUNCTION IF EXISTS enforce_hr_admin_slot_limit();

-- Optional text printed on salary slip PDF
ALTER TABLE "monthly_payroll" ADD COLUMN IF NOT EXISTS "slip_notes" TEXT;
