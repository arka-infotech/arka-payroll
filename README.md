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

## Bootstrap

```bash
# 1. Database
docker compose up -d

# 2. Backend
cp .env.example backend/.env
cd backend && npm install
npx prisma migrate deploy
npm run prisma:seed
npm run start:dev

# 3. Frontend (new terminal)
cd frontend
flutter create --platforms=web,macos,windows,linux .
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

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
