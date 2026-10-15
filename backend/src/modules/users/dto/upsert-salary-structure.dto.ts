import {
  IsBoolean,
  IsDateString,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

/**
 * Salary structure DTO.
 * Basic must be 40–50% of annual CTC; HRA 40–50% of Basic.
 * Special allowance typically absorbs the residual monthly CTC.
 */
export class UpsertSalaryStructureDto {
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  annualCtc!: number;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  basicMonthly!: number;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  hraMonthly!: number;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  specialAllowanceMonthly!: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  conveyanceMonthly?: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  medicalMonthly?: number;

  @IsOptional()
  @IsBoolean()
  epfApplicable?: boolean;

  @IsOptional()
  @IsString()
  taxRegime?: 'NEW' | 'OLD';

  @IsDateString()
  effectiveFrom!: string;
}
