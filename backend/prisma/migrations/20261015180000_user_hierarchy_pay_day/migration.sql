ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "created_by_id" UUID;

ALTER TABLE "salary_structures" ADD COLUMN IF NOT EXISTS "salary_credit_day" INTEGER NOT NULL DEFAULT 1;

CREATE INDEX IF NOT EXISTS "users_created_by_id_idx" ON "users"("created_by_id");
