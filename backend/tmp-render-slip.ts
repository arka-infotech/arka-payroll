import { writeFileSync } from 'fs';
import { ConfigService } from '@nestjs/config';
import { PdfSlipService } from './src/modules/payroll/pdf-slip.service';

async function main() {
  const config = new ConfigService({
    COMPANY_NAME: 'Arka Infotech Software Solutions',
    COMPANY_COUNTRY: 'India',
  });
  const svc = new PdfSlipService(config);
  const buffer = await svc.renderA4({
    year: 2026,
    month: 9,
    trackingReference: 'sample',
    workingDaysInMonth: 31,
    daysPayable: 31,
    unpaidLeaveDays: 0,
    basicEarned: 25000,
    hraEarned: 0,
    specialAllowanceEarned: 0,
    conveyanceEarned: 1880,
    medicalEarned: 0,
    bonus: 0,
    specialAdjustment: 0,
    otherEarnings: 0,
    grossEarnings: 26880,
    epfEmployee: 0,
    esicEmployee: 0,
    professionalTax: 0,
    tds: 0,
    otherDeductions: 0,
    totalDeductions: 0,
    netPay: 26880,
    payDate: new Date('2026-10-03'),
    user: {
      firstName: 'Dhruv',
      lastName: 'Shetty',
      employeeCode: 'A123',
      designation: null,
      dateOfJoining: null,
      pan: null,
      uan: null,
      bankName: null,
      bankAccountNumber: null,
      bankIfsc: null,
      email: 'a@b.c',
    },
  });
  writeFileSync('tmp-sample-slip.pdf', buffer);
  await svc.onModuleDestroy();
}

main();
