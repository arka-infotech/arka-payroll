import { Module } from '@nestjs/common';
import { PayrollService } from './payroll.service';
import { PayrollController } from './payroll.controller';
import { PdfSlipService } from './pdf-slip.service';

@Module({
  controllers: [PayrollController],
  providers: [PayrollService, PdfSlipService],
  exports: [PayrollService],
})
export class PayrollModule {}
