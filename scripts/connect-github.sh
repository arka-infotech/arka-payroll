#!/usr/bin/env bash
# Connect this monorepo to the existing GitHub remote and push.
# Run from the repo root (outside restricted sandboxes):
#   chmod +x scripts/connect-github.sh && ./scripts/connect-github.sh

set -euo pipefail

REMOTE_URL="https://github.com/DhruvShetty4474/Arka-payroll.git"

cd "$(dirname "$0")/.."

if [ ! -d .git ]; then
  git init
fi

git branch -M main

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE_URL"
else
  git remote add origin "$REMOTE_URL"
fi

echo "Remote configured:"
git remote -v

echo ""
echo "Next (when ready to publish this scaffold):"
echo "  git add ."
echo "  git commit -m \"scaffold: Arka payroll monorepo (NestJS + Flutter)\""
echo "  git pull origin main --allow-unrelated-histories   # if README already on remote"
echo "  git push -u origin main"
