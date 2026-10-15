-- Arka Infotech Software Solutions LLP — Initial payroll schema
-- Creates enums, tables, constraints, and indexes for compliance-first payroll.

CREATE TYPE "Role" AS ENUM ('SUPER_ADMIN', 'HR_ADMIN', 'EMPLOYEE');
CREATE TYPE "EmploymentStatus" AS ENUM ('ACTIVE', 'INACTIVE', 'TERMINATED');
CREATE TYPE "PayrollStatus" AS ENUM ('DRAFT', 'PROCESSED', 'LOCKED', 'PAID');

-- ─── users ───────────────────────────────────────────────────────────────────
CREATE TABLE "users" (
    "id"                  UUID NOT NULL,
    "email"               TEXT NOT NULL,
    "password_hash"       TEXT NOT NULL,
    "role"                "Role" NOT NULL DEFAULT 'EMPLOYEE',
    "employee_code"       TEXT,
    "first_name"          TEXT NOT NULL,
    "last_name"           TEXT NOT NULL,
    "designation"         TEXT,
    "date_of_joining"     DATE,
    "status"              "EmploymentStatus" NOT NULL DEFAULT 'ACTIVE',
    "pan"                 CHAR(10),
    "aadhaar"             CHAR(12),
    "uan"                 VARCHAR(12),
    "bank_name"           TEXT,
    "bank_account_number" TEXT,
    "bank_ifsc"           VARCHAR(11),
    "created_at"          TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at"          TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "users_email_key" ON "users"("email");
CREATE UNIQUE INDEX "users_employee_code_key" ON "users"("employee_code");
CREATE INDEX "users_role_status_idx" ON "users"("role", "status");

-- Enforce max 2 active HR Admin slots at the database level
CREATE OR REPLACE FUNCTION enforce_hr_admin_slot_limit()
RETURNS TRIGGER AS $$
DECLARE
  active_hr_count INTEGER;
BEGIN
  IF NEW.role = 'HR_ADMIN' AND NEW.status = 'ACTIVE' THEN
    SELECT COUNT(*) INTO active_hr_count
    FROM "users"
    WHERE role = 'HR_ADMIN'
      AND status = 'ACTIVE'
      AND id <> NEW.id;

    IF active_hr_count >= 2 THEN
      RAISE EXCEPTION 'HR_ADMIN active slot limit (2) exceeded';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_hr_admin_slot_limit
  BEFORE INSERT OR UPDATE ON "users"
  FOR EACH ROW
  EXECUTE FUNCTION enforce_hr_admin_slot_limit();

-- ─── salary_structures ───────────────────────────────────────────────────────
CREATE TABLE "salary_structures" (
    "id"                        UUID NOT NULL,
    "user_id"                   UUID NOT NULL,
    "annual_ctc"                DECIMAL(14,2) NOT NULL,
    "basic_monthly"             DECIMAL(12,2) NOT NULL,
    "hra_monthly"               DECIMAL(12,2) NOT NULL,
    "special_allowance_monthly" DECIMAL(12,2) NOT NULL,
    "conveyance_monthly"        DECIMAL(12,2) NOT NULL DEFAULT 0,
    "medical_monthly"           DECIMAL(12,2) NOT NULL DEFAULT 0,
    "epf_applicable"            BOOLEAN NOT NULL DEFAULT true,
    "tax_regime"                VARCHAR(8) NOT NULL DEFAULT 'NEW',
    "effective_from"            DATE NOT NULL,
    "created_at"                TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at"                TIMESTAMP(3) NOT NULL,

    CONSTRAINT "salary_structures_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "salary_structures_user_id_fkey"
      FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "salary_structures_basic_pct_chk"
      CHECK ("basic_monthly" * 12 >= "annual_ctc" * 0.40
         AND "basic_monthly" * 12 <= "annual_ctc" * 0.50),
    CONSTRAINT "salary_structures_hra_pct_chk"
      CHECK ("hra_monthly" >= "basic_monthly" * 0.40
         AND "hra_monthly" <= "basic_monthly" * 0.50)
);

CREATE UNIQUE INDEX "salary_structures_user_id_key" ON "salary_structures"("user_id");

-- ─── monthly_payroll ─────────────────────────────────────────────────────────
CREATE TABLE "monthly_payroll" (
    "id"                       UUID NOT NULL,
    "user_id"                  UUID NOT NULL,
    "year"                     INTEGER NOT NULL,
    "month"                    INTEGER NOT NULL,
    "working_days_in_month"    INTEGER NOT NULL,
    "days_payable"             INTEGER NOT NULL,
    "unpaid_leave_days"        INTEGER NOT NULL DEFAULT 0,
    "bonus"                    DECIMAL(12,2) NOT NULL DEFAULT 0,
    "special_adjustment"       DECIMAL(12,2) NOT NULL DEFAULT 0,
    "other_earnings"           DECIMAL(12,2) NOT NULL DEFAULT 0,
    "basic_earned"             DECIMAL(12,2) NOT NULL,
    "hra_earned"               DECIMAL(12,2) NOT NULL,
    "special_allowance_earned" DECIMAL(12,2) NOT NULL,
    "conveyance_earned"        DECIMAL(12,2) NOT NULL DEFAULT 0,
    "medical_earned"           DECIMAL(12,2) NOT NULL DEFAULT 0,
    "gross_earnings"           DECIMAL(12,2) NOT NULL,
    "epf_employee"             DECIMAL(12,2) NOT NULL,
    "professional_tax"         DECIMAL(12,2) NOT NULL,
    "tds"                      DECIMAL(12,2) NOT NULL,
    "other_deductions"         DECIMAL(12,2) NOT NULL DEFAULT 0,
    "total_deductions"         DECIMAL(12,2) NOT NULL,
    "net_pay"                  DECIMAL(12,2) NOT NULL,
    "tracking_reference"       TEXT NOT NULL,
    "status"                   "PayrollStatus" NOT NULL DEFAULT 'DRAFT',
    "processed_at"             TIMESTAMP(3),
    "processed_by"             UUID,
    "calculation_snapshot"     JSONB,
    "created_at"               TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at"               TIMESTAMP(3) NOT NULL,

    CONSTRAINT "monthly_payroll_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "monthly_payroll_user_id_fkey"
      FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "monthly_payroll_month_chk" CHECK ("month" >= 1 AND "month" <= 12),
    CONSTRAINT "monthly_payroll_days_chk"
      CHECK ("days_payable" >= 0 AND "days_payable" <= "working_days_in_month"),
    CONSTRAINT "monthly_payroll_net_chk"
      CHECK ("net_pay" = "gross_earnings" - "total_deductions")
);

CREATE UNIQUE INDEX "monthly_payroll_tracking_reference_key"
  ON "monthly_payroll"("tracking_reference");
CREATE UNIQUE INDEX "monthly_payroll_user_id_year_month_key"
  ON "monthly_payroll"("user_id", "year", "month");
CREATE INDEX "monthly_payroll_year_month_status_idx"
  ON "monthly_payroll"("year", "month", "status");
