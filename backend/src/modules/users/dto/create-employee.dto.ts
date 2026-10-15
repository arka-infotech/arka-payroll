import {
  IsDateString,
  IsEmail,
  IsEnum,
  IsOptional,
  IsString,
  Length,
  Matches,
  MinLength,
} from 'class-validator';
import { AppRole } from '../../../common/enums/role.enum';

export class CreateEmployeeDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(8)
  password!: string;

  @IsString()
  firstName!: string;

  @IsString()
  lastName!: string;

  @IsOptional()
  @IsString()
  employeeCode?: string;

  @IsOptional()
  @IsString()
  designation?: string;

  @IsOptional()
  @IsDateString()
  dateOfJoining?: string;

  /** Only HR_ADMIN or EMPLOYEE may be created via API. SUPER_ADMIN is seed-only. */
  @IsEnum([AppRole.HR_ADMIN, AppRole.EMPLOYEE])
  role!: AppRole.HR_ADMIN | AppRole.EMPLOYEE;

  @IsOptional()
  @IsString()
  @Length(10, 10)
  @Matches(/^[A-Z]{5}[0-9]{4}[A-Z]$/)
  pan?: string;

  @IsOptional()
  @IsString()
  @Length(12, 12)
  @Matches(/^[0-9]{12}$/)
  aadhaar?: string;

  @IsOptional()
  @IsString()
  @Length(12, 12)
  uan?: string;

  @IsOptional()
  @IsString()
  bankName?: string;

  @IsOptional()
  @IsString()
  bankAccountNumber?: string;

  @IsOptional()
  @IsString()
  @Length(11, 11)
  bankIfsc?: string;
}
