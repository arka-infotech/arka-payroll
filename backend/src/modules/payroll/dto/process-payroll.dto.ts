import {
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

/** HR punches monthly variables for a single employee before processing. */
export class ProcessPayrollDto {
  @IsUUID()
  userId!: string;

  @IsInt()
  @Min(2000)
  @Max(2100)
  year!: number;

  @IsInt()
  @Min(1)
  @Max(12)
  month!: number;

  @IsInt()
  @Min(1)
  @Max(31)
  workingDaysInMonth!: number;

  @IsInt()
  @Min(0)
  @Max(31)
  unpaidLeaveDays!: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  bonus?: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  specialAdjustment?: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  otherEarnings?: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  otherDeductions?: number;

  @IsOptional()
  @IsBoolean()
  epfOnActuals?: boolean;

  /** Printed on the PDF slip when set (max 500 chars). */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  slipNotes?: string;
}
