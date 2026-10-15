import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { IsString, MinLength } from 'class-validator';
import { PayrollService } from './payroll.service';
import { ProcessPayrollDto } from './dto/process-payroll.dto';
import { UpdateSlipDocumentDto } from './dto/update-slip-document.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { AppRole } from '../../common/enums/role.enum';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/interfaces/jwt-payload.interface';

class UnlockPayrollDto extends ProcessPayrollDto {
  @IsString()
  @MinLength(8)
  superAdminPassword!: string;
}

@Controller('payroll')
@UseGuards(JwtAuthGuard, RolesGuard)
export class PayrollController {
  constructor(private readonly payrollService: PayrollService) {}

  @Get('stats')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  stats() {
    return this.payrollService.dashboardStats();
  }

  @Get('grid')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  grid(
    @Query('year', ParseIntPipe) year: number,
    @Query('month', ParseIntPipe) month: number,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.payrollService.listPayrollGridSeed(year, month, user);
  }

  @Get('period')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  listPeriod(
    @Query('year', ParseIntPipe) year: number,
    @Query('month', ParseIntPipe) month: number,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.payrollService.listForPeriod(year, month, user);
  }

  @Post('save-draft')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  saveDraft(@Body() dto: ProcessPayrollDto, @CurrentUser() user: JwtPayload) {
    return this.payrollService.saveDraft(dto, user);
  }

  @Get('my')
  @Roles(AppRole.EMPLOYEE, AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  mySlips(@CurrentUser() user: JwtPayload) {
    return this.payrollService.listMySlips(user.sub);
  }

  @Post('preview')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  preview(@Body() dto: ProcessPayrollDto, @CurrentUser() user: JwtPayload) {
    return this.payrollService.preview(dto, user);
  }

  @Post('process')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  process(@Body() dto: ProcessPayrollDto, @CurrentUser() user: JwtPayload) {
    return this.payrollService.processMonthly(dto, user);
  }

  /** Overwrite a LOCKED slip — requires Super Admin password. */
  @Post('unlock-reprocess')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  unlockReprocess(
    @Body() dto: UnlockPayrollDto,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.payrollService.unlockAndReprocess(dto, user);
  }

  @Post('process-batch')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  processBatch(
    @Body()
    body: {
      year: number;
      month: number;
      entries: ProcessPayrollDto[];
    },
    @CurrentUser() user: JwtPayload,
  ) {
    return this.payrollService.processBatch(
      body.year,
      body.month,
      body.entries,
      user,
    );
  }

  @Patch(':id/document')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  updateDocument(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateSlipDocumentDto,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.payrollService.updateSlipDocument(id, dto, user);
  }

  @Get(':id')
  @Roles(AppRole.EMPLOYEE, AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  getOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.payrollService.getSlipMeta(id, user);
  }

  @Get(':id/pdf')
  @Roles(AppRole.EMPLOYEE, AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  async pdf(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Res() res: Response,
  ) {
    const { buffer, filename } = await this.payrollService.generatePdfBuffer(
      id,
      user,
    );
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="${filename.replace(/"/g, '')}"`,
    );
    res.send(buffer);
  }
}
