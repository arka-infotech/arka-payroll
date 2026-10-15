import { Role } from '@prisma/client';
import { Prisma } from '@prisma/client';
import { AppRole } from '../../common/enums/role.enum';

/** Super Admin sees everyone except hidden root duplicates. HR Admin: self + all employees, not peer admins. */
export function visibleUsersWhere(
  requester: { sub: string; role: AppRole },
): Prisma.UserWhereInput {
  if (requester.role === AppRole.SUPER_ADMIN) {
    return { role: { not: Role.SUPER_ADMIN } };
  }
  return {
    role: { not: Role.SUPER_ADMIN },
    OR: [{ role: Role.EMPLOYEE }, { id: requester.sub }],
  };
}

export function canManageUser(
  requester: { sub: string; role: AppRole },
  target: { id: string; role: Role },
): boolean {
  if (requester.role === AppRole.SUPER_ADMIN) return true;
  if (target.role === Role.SUPER_ADMIN) return false;
  if (target.role === Role.HR_ADMIN && target.id !== requester.sub) return false;
  return true;
}
