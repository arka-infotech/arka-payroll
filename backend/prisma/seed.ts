/**
 * Seed — upserts the hidden Super Admin root account.
 * Deletes any previous SUPER_ADMIN rows that do not match SUPER_ADMIN_EMAIL.
 */
import { PrismaClient, Role, EmploymentStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';

const prisma = new PrismaClient();

async function main(): Promise<void> {
  const email = (
    process.env.SUPER_ADMIN_EMAIL ?? 'shettydhruv986@gmail.com'
  )
    .toLowerCase()
    .trim();
  const plainPassword =
    process.env.SUPER_ADMIN_PASSWORD ?? 'Mango@4414';

  const passwordHash = await bcrypt.hash(plainPassword, 12);

  // Remove other Super Admin accounts (hidden root is singular)
  await prisma.user.deleteMany({
    where: {
      role: Role.SUPER_ADMIN,
      NOT: { email },
    },
  });

  const existing = await prisma.user.findUnique({ where: { email } });

  if (existing) {
    await prisma.user.update({
      where: { email },
      data: {
        passwordHash,
        role: Role.SUPER_ADMIN,
        status: EmploymentStatus.ACTIVE,
        firstName: existing.firstName || 'Dhruv',
        lastName: existing.lastName || 'Shetty',
        designation: 'Super Administrator',
        bannedAt: null,
        bannedReason: null,
      },
    });
    console.log(`[seed] Super Admin updated: ${email}`);
    return;
  }

  await prisma.user.create({
    data: {
      id: randomUUID(),
      email,
      passwordHash,
      role: Role.SUPER_ADMIN,
      firstName: 'Dhruv',
      lastName: 'Shetty',
      designation: 'Super Administrator',
      status: EmploymentStatus.ACTIVE,
      employeeCode: null,
    },
  });

  console.log(`[seed] Super Admin created: ${email}`);
}

main()
  .catch((err) => {
    console.error('[seed] Failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
