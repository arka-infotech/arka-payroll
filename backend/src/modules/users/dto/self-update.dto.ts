import {
  IsOptional,
  IsString,
  Length,
  Matches,
  MinLength,
  ValidateIf,
} from 'class-validator';

/** Fields an employee may complete on their own profile. */
export class SelfUpdateProfileDto {
  @IsOptional()
  @ValidateIf((_, v) => typeof v === 'string' && v.trim().length > 0)
  @IsString()
  @Length(10, 10)
  @Matches(/^[A-Z]{5}[0-9]{4}[A-Z]$/)
  pan?: string;

  @IsOptional()
  @ValidateIf(
    (_, v) => typeof v === 'string' && v.trim().length > 0 && v !== 'N/A',
  )
  @IsString()
  @Length(12, 12)
  @Matches(/^[0-9]{12}$/)
  aadhaar?: string | null;

  @IsOptional()
  @ValidateIf(
    (_, v) => typeof v === 'string' && v.trim().length > 0 && v !== 'N/A',
  )
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
