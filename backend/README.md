# Arka Payroll — Backend (NestJS + Prisma)

## Stack

- NestJS (TypeScript) — clean module layers
- Prisma → PostgreSQL 16
- JWT + RBAC (`SUPER_ADMIN` | `HR_ADMIN` | `EMPLOYEE`)
- Puppeteer — A4 salary-slip PDFs

## Quick start

```bash
# From repo root
cp .env.example backend/.env
docker compose up -d
cd backend
npm install
npx prisma migrate deploy
npm run prisma:seed
npm run start:dev
```

API: `http://localhost:3000/api/v1/health`

## RBAC summary

| Role | Capabilities |
|------|----------------|
| **HR Admin** (max 2 active) | List employees, punch monthly vars, process & print slips |
| **Employee** | View/download own slips only |
| **Super Admin** | Full access; **seeded only**; **excluded from all UI user lists** |

## Key endpoints

| Method | Path | Role |
|--------|------|------|
| POST | `/auth/login` | public |
| GET | `/auth/me` | any auth |
| GET | `/users` | HR / Super |
| POST | `/payroll/process` | HR / Super |
| GET | `/payroll/grid?year=&month=` | HR / Super |
| GET | `/payroll/my` | self |
| GET | `/payroll/:id/pdf` | owner or HR |

## Calculation notes

- **EPF**: 12% of PF wages, default ceiling ₹15,000 (toggle `epfOnActuals`)
- **Professional Tax**: Karnataka slabs (Bengaluru default)
- **TDS**: Simplified new-regime monthly estimate (replace with YTD engine for production)
