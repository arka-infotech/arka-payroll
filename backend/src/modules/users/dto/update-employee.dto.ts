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

/** Profile fields an admin can change for a visible user. */
export class UpdateEmployeeDto {
  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  @MinLength(8)
  password?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  firstName?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  lastName?: string;

  @IsOptional()
  @IsString()
  @Matches(/^AISS.+$/i, {
    message: 'Employee ID must start with AISS',
  })
  employeeCode?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  designation?: string;

  @IsOptional()
  @IsDateString()
  dateOfJoining?: string;

  @IsOptional()
  @IsEnum([AppRole.HR_ADMIN, AppRole.EMPLOYEE])
  role?: AppRole.HR_ADMIN | AppRole.EMPLOYEE;

  @IsOptional()
  @IsString()
  @Length(10, 10)
  @Matches(/^[A-Z]{5}[0-9]{4}[A-Z]$/)
  pan?: string;

  @IsOptional()
  @ValidateIf((_, v) => typeof v === 'string' && v.trim().length > 0 && v !== 'N/A')
  @IsString()
  @Length(12, 12)
  @Matches(/^[0-9]{12}$/)
  aadhaar?: string | null;

  @IsOptional()
  @ValidateIf((_, v) => typeof v === 'string' && v.trim().length > 0 && v !== 'N/A')
  @IsString()
  @Length(12, 12)
  uan?: string | null;

  @IsOptional()
  @IsString()
  @MinLength(1)
  bankName?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  bankAccountNumber?: string;

  @IsOptional()
  @IsString()
  @Length(11, 11)
  bankIfsc?: string;
}
