import { Transform, Type } from 'class-transformer';
import {
  IsArray,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

/** Coerce JSON numbers/strings and round to 2dp so float noise does not 400/500. */
function toMoney(value: unknown): number {
  const n = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(n)) return 0;
  return Math.round(n * 100) / 100;
}

function toInt(value: unknown): number {
  const n = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(n)) return 0;
  return Math.trunc(n);
}

export class SlipLineDto {
  @IsString()
  @MaxLength(80)
  label!: string;

  @Transform(({ value }) => toMoney(value))
  @IsNumber()
  amount!: number;
}

/** Full payslip content an admin can change after punch. */
export class UpdateSlipDocumentDto {
  @IsOptional()
  @IsString()
  @MaxLength(160)
  companyName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(400)
  location?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  employeeName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  employeeCode?: string;

  @IsOptional()
  @IsString()
  payDate?: string;

  /** Printed pay period range, e.g. "1 Sep 26 - 30 Sep 26". */
  @IsOptional()
  @IsString()
  @MaxLength(60)
  payPeriod?: string;

  /** Header label, e.g. "September 2026". */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  payslipMonth?: string;

  @Transform(({ value }) => toInt(value))
  @IsInt()
  @Min(0)
  @Max(31)
  paidDays!: number;

  @Transform(({ value }) => toInt(value))
  @IsInt()
  @Min(0)
  @Max(31)
  lopDays!: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SlipLineDto)
  earnings!: SlipLineDto[];

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SlipLineDto)
  deductions!: SlipLineDto[];
}
