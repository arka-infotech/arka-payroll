import { Role } from '@prisma/client';
import { Prisma } from '@prisma/client';
import { AppRole } from '../../common/enums/role.enum';

/**
 * Super Admin and HR Admin both see HR admins + employees.
 * Super Admin is never returned in lists or detail lookups.
 */
export function visibleUsersWhere(
  _requester: { sub: string; role: AppRole },
): Prisma.UserWhereInput {
  return { role: { not: Role.SUPER_ADMIN } };
}

export function canManageUser(
  requester: { sub: string; role: AppRole },
  target: { id: string; role: Role },
): boolean {
  if (target.role === Role.SUPER_ADMIN) return false;
  if (requester.role === AppRole.SUPER_ADMIN) return true;
  if (requester.role === AppRole.HR_ADMIN) return true;
  return target.id === requester.sub;
}
