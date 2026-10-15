/**
 * Seed script — creates the hidden Super Admin root account.
 * Run: npm run prisma:seed
 *
 * SUPER_ADMIN is never returned by standard user-list APIs.
 */
import { PrismaClient, Role, EmploymentStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';

const prisma = new PrismaClient();

async function main(): Promise<void> {
  const email =
    process.env.SUPER_ADMIN_EMAIL ?? 'root@arkainfotech.internal';
  const plainPassword =
    process.env.SUPER_ADMIN_PASSWORD ?? 'ChangeMeImmediately!2026';

  const passwordHash = await bcrypt.hash(plainPassword, 12);

  const existing = await prisma.user.findUnique({ where: { email } });

  if (existing) {
    console.log(`[seed] Super Admin already exists: ${email}`);
    return;
  }

  await prisma.user.create({
    data: {
      id: randomUUID(),
      email,
      passwordHash,
      role: Role.SUPER_ADMIN,
      firstName: 'System',
      lastName: 'Root',
      designation: 'Super Administrator',
      status: EmploymentStatus.ACTIVE,
      employeeCode: null,
    },
  });

  console.log(`[seed] Super Admin created: ${email}`);
  console.log('[seed] Change SUPER_ADMIN_PASSWORD immediately in production.');
}

main()
  .catch((err) => {
    console.error('[seed] Failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
