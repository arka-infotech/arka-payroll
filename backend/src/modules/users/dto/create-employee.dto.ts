import {
  IsDateString,
  IsEmail,
  IsEnum,
  IsOptional,
  IsString,
  Length,
  Matches,
  MinLength,
  ValidateIf,
} from 'class-validator';
import { AppRole } from '../../../common/enums/role.enum';

export class CreateEmployeeDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(8)
  password!: string;

  @IsString()
  @MinLength(1)
  firstName!: string;

  @IsString()
  @MinLength(1)
  lastName!: string;

  /** Must start with AISS (e.g. AISS001). */
  @IsString()
  @Matches(/^AISS.+$/i, {
    message: 'Employee ID must start with AISS',
  })
  employeeCode!: string;

  @IsString()
  @MinLength(1)
  designation!: string;

  @IsDateString()
  dateOfJoining!: string;

  /** Only HR_ADMIN or EMPLOYEE may be created via API. SUPER_ADMIN is seed-only. */
  @IsEnum([AppRole.HR_ADMIN, AppRole.EMPLOYEE])
  role!: AppRole.HR_ADMIN | AppRole.EMPLOYEE;

  @IsString()
  @Length(10, 10)
  @Matches(/^[A-Z]{5}[0-9]{4}[A-Z]$/)
  pan!: string;

  @IsOptional()
  @ValidateIf((_, v) => typeof v === 'string' && v.trim().length > 0 && v !== 'N/A')
  @IsString()
  @Length(12, 12)
  @Matches(/^[0-9]{12}$/)
  aadhaar?: string;

  @IsOptional()
  @ValidateIf((_, v) => typeof v === 'string' && v.trim().length > 0 && v !== 'N/A')
  @IsString()
  @Length(12, 12)
  uan?: string;

  @IsString()
  @MinLength(1)
  bankName!: string;

  @IsString()
  @MinLength(1)
  bankAccountNumber!: string;

  @IsString()
  @Length(11, 11)
  bankIfsc!: string;
}
