# Arka Payroll

Internal payroll & salary-slip system for **Arka Infotech Software Solutions LLP**.

```
arka-payroll/
├── backend/          # NestJS + Prisma + PostgreSQL API
├── frontend/         # Flutter (Web / Desktop)
├── docker-compose.yml
└── .env.example
```

## Architecture

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Web, macOS, Windows, Linux) |
| Backend | NestJS (TypeScript), clean modules |
| Database | PostgreSQL 16 via Prisma |
| Auth | JWT + RBAC |
| PDFs | Puppeteer A4 HTML → PDF |

### Roles

1. **HR Admin** — max **2 active** slots (DB trigger enforced). Punch monthly variables, process payroll, print slips.
2. **Employee** — view & download **own** salary slips only.
3. **Super Admin** — hidden root, seeded via `prisma/seed.ts`. **Never** returned in standard user-list APIs.

## Prerequisites

- Node.js ≥ 20
- Docker (PostgreSQL)
- Flutter SDK ≥ 3.3 (for the client)

## Bootstrap (no Docker required)

Docker Desktop is optional. If `docker` is not installed, use the embedded Postgres helper:

```bash
# Terminal 1 — database (keep running)
./scripts/dev-db.sh

# Terminal 2 — API
cp .env.example backend/.env
cd backend && npm install
npx prisma migrate deploy
npm run prisma:seed
npm run start:dev

# Terminal 3 — Flutter client
cd frontend
flutter create --platforms=web,macos,windows,linux .   # first time only
flutter pub get
flutter run -d macos --dart-define=API_BASE_URL=http://localhost:3000/api/v1
# or: flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

### If you prefer Docker

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/), then:

```bash
docker compose up -d
# continue with Terminal 2 + 3 above (skip ./scripts/dev-db.sh)
```

### Common errors

| Error | Cause | Fix |
|-------|--------|-----|
| `zsh: command not found: docker` | Docker not installed | Use `./scripts/dev-db.sh` or install Docker Desktop |
| `Can't reach database server at localhost:5432` | Postgres not running | Start `./scripts/dev-db.sh` or `docker compose up -d` first |
| Flutter `Uint8List` / PDF errors | Fixed in current code | `git pull` then `flutter pub get` |
| Frontend login fails / connection refused | API not running | Start backend on port 3000 |

Default Super Admin (change immediately):

- Email: `root@arkainfotech.internal`
- Password: `ChangeMeImmediately!2026`

## Compliance highlights

- Users store PAN, Aadhaar, UAN, bank details, DOJ, designation
- Salary structures enforce Basic 40–50% of CTC and HRA 40–50% of Basic
- Monthly payroll tracks gross, EPF, Professional Tax, TDS, net pay + unique tracking reference
- Slip disclaimer: *"This is a computer-generated document and requires no physical signature."*
- Payroll writes run inside a **Prisma interactive SQL transaction**

## Repository

Remote: [https://github.com/DhruvShetty4474/Arka-payroll](https://github.com/DhruvShetty4474/Arka-payroll)

```bash
git remote add origin https://github.com/DhruvShetty4474/Arka-payroll.git
git branch -M main
git push -u origin main
```

## License

UNLICENSED — internal use only.
