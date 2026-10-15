/** Mirrors Prisma Role enum for use in decorators / guards without circular deps. */
export enum AppRole {
  SUPER_ADMIN = 'SUPER_ADMIN',
  HR_ADMIN = 'HR_ADMIN',
  EMPLOYEE = 'EMPLOYEE',
}

/** Roles visible in standard UI user lists (excludes hidden Super Admin). */
export const VISIBLE_ROLES: AppRole[] = [AppRole.HR_ADMIN, AppRole.EMPLOYEE];
