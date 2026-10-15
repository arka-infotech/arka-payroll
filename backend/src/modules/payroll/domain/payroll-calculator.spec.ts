import { computeMonthlyPayroll } from './payroll-calculator';
import { calculateMaharashtraProfessionalTax } from './professional-tax.calculator';

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

assert(calculateMaharashtraProfessionalTax(7000, 1) === 0, 'PT nil slab');
assert(calculateMaharashtraProfessionalTax(8000, 1) === 175, 'PT mid slab');
assert(calculateMaharashtraProfessionalTax(20000, 1) === 200, 'PT high slab');
assert(calculateMaharashtraProfessionalTax(20000, 3) === 300, 'March PT bump');

const structure = {
  annualCtc: 600000,
  basicMonthly: 20000,
  hraMonthly: 8000,
  specialAllowanceMonthly: 18000,
  conveyanceMonthly: 0,
  medicalMonthly: 0,
  epfApplicable: false,
  esicApplicable: false,
  professionalTaxApplicable: true,
  tdsApplicable: true,
  taxRegime: 'NEW',
};

const result = computeMonthlyPayroll(structure, {
  year: 2026,
  month: 3,
  workingDaysInMonth: 31,
  unpaidLeaveDays: 0,
  bonus: 0,
  specialAdjustment: 0,
  otherEarnings: 0,
  otherDeductions: 0,
});

assert(result.epfEmployee === 0, 'EPF must be 0 when not applicable');
assert(result.esicEmployee === 0, 'ESIC must be 0 when not applicable');
assert(result.professionalTax === 300, 'March PT must be 300');
assert(
  Math.abs(result.netPay - (result.grossEarnings - result.totalDeductions)) < 0.01,
  'Net identity',
);

console.log('payroll-calculator.spec.ts: all assertions passed', {
  gross: result.grossEarnings,
  pt: result.professionalTax,
  net: result.netPay,
});
