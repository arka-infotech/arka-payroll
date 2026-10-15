import {
  Body,
  Controller,
  Get,
  Header,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Post,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { PayrollService } from './payroll.service';
import { ProcessPayrollDto } from './dto/process-payroll.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { AppRole } from '../../common/enums/role.enum';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/interfaces/jwt-payload.interface';

@Controller('payroll')
@UseGuards(JwtAuthGuard, RolesGuard)
export class PayrollController {
  constructor(private readonly payrollService: PayrollService) {}

  /** HR grid seed: employees + existing run for a period. */
  @Get('grid')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  grid(
    @Query('year', ParseIntPipe) year: number,
    @Query('month', ParseIntPipe) month: number,
  ) {
    return this.payrollService.listPayrollGridSeed(year, month);
  }

  @Get('period')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  listPeriod(
    @Query('year', ParseIntPipe) year: number,
    @Query('month', ParseIntPipe) month: number,
  ) {
    return this.payrollService.listForPeriod(year, month);
  }

  /** Employee: own slips only. */
  @Get('my')
  @Roles(AppRole.EMPLOYEE, AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  mySlips(@CurrentUser() user: JwtPayload) {
    return this.payrollService.listMySlips(user.sub);
  }

  @Post('process')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  process(
    @Body() dto: ProcessPayrollDto,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.payrollService.processMonthly(dto, user.sub);
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
      user.sub,
    );
  }

  @Get(':id')
  @Roles(AppRole.EMPLOYEE, AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  getOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.payrollService.getSlipMeta(id, user);
  }

  /** A4 PDF download / print source. */
  @Get(':id/pdf')
  @Roles(AppRole.EMPLOYEE, AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  @Header('Content-Type', 'application/pdf')
  async pdf(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Res() res: Response,
  ) {
    const { buffer, filename } = await this.payrollService.generatePdfBuffer(
      id,
      user,
    );
    res.setHeader(
      'Content-Disposition',
      `inline; filename="${filename}"`,
    );
    res.send(buffer);
  }
}
