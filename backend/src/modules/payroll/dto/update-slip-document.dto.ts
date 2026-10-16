import { Type } from 'class-transformer';
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

export class SlipLineDto {
  @IsString()
  @MaxLength(80)
  label!: string;

  @IsNumber({ maxDecimalPlaces: 2 })
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

  @IsInt()
  @Min(0)
  @Max(31)
  paidDays!: number;

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
