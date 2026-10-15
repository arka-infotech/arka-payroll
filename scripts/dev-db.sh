#!/usr/bin/env bash
# Start embedded PostgreSQL (no Docker required).
# Usage from repo root:  ./scripts/dev-db.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# Ensure native binary postinstall ran
npm rebuild @embedded-postgres/darwin-arm64 --workspace=backend 2>/dev/null || true
node "$ROOT/scripts/dev-db.mjs"
