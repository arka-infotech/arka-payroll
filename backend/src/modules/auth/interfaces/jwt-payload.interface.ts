import { AppRole } from '../../../common/enums/role.enum';

export interface JwtPayload {
  sub: string;
  email: string;
  role: AppRole;
  employeeCode?: string | null;
}
