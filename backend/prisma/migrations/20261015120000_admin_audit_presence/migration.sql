-- Presence + ban support + Super-Admin-only audit trail

DO $$ BEGIN
  ALTER TYPE "EmploymentStatus" ADD VALUE 'BANNED';
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "last_seen_at" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "banned_at" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "banned_reason" TEXT;

CREATE TABLE IF NOT EXISTS "audit_logs" (
    "id"           UUID NOT NULL,
    "actor_id"     UUID,
    "actor_email"  TEXT,
    "actor_role"   "Role",
    "action"       TEXT NOT NULL,
    "entity"       TEXT NOT NULL,
    "entity_id"    TEXT,
    "summary"      TEXT NOT NULL,
    "metadata"     JSONB,
    "ip_address"   TEXT,
    "created_at"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "audit_logs_created_at_idx" ON "audit_logs"("created_at" DESC);
CREATE INDEX IF NOT EXISTS "audit_logs_actor_id_idx" ON "audit_logs"("actor_id");
CREATE INDEX IF NOT EXISTS "audit_logs_entity_idx" ON "audit_logs"("entity", "entity_id");
