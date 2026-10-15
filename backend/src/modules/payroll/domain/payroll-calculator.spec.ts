/**
 * Lightweight domain tests (run with: npx ts-node or jest when configured).
 * Validates EPF ceiling, PT slabs, and net-pay identity.
 */
import { computeMonthlyPayroll } from './payroll-calculator';
import { calculateEmployeeEpf, EPF_WAGE_CEILING } from './epf.calculator';
import { calculateKarnatakaProfessionalTax } from './professional-tax.calculator';

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

const structure = {
  annualCtc: 1200000,
  basicMonthly: 40000, // 40% of CTC
  hraMonthly: 16000, // 40% of basic
  specialAllowanceMonthly: 40000,
  conveyanceMonthly: 0,
  medicalMonthly: 0,
  epfApplicable: true,
  taxRegime: 'NEW',
};

const result = computeMonthlyPayroll(structure, {
  year: 2026,
  month: 3,
  workingDaysInMonth: 22,
  unpaidLeaveDays: 0,
  bonus: 5000,
  specialAdjustment: 0,
  otherEarnings: 0,
  otherDeductions: 0,
});

assert(
  Math.abs(result.netPay - (result.grossEarnings - result.totalDeductions)) < 0.01,
  'Net must equal Gross − Deductions',
);

assert(
  calculateEmployeeEpf(40000) ===
    Math.round(EPF_WAGE_CEILING * 0.12 * 100) / 100,
  'EPF must respect ₹15,000 ceiling',
);

assert(calculateKarnatakaProfessionalTax(20000, 3) === 200, 'PT slab failed');
assert(calculateKarnatakaProfessionalTax(10000, 3) === 0, 'PT nil slab failed');
assert(calculateKarnatakaProfessionalTax(20000, 2) === 300, 'Feb PT failed');

console.log('payroll-calculator.spec.ts: all assertions passed');
console.log({
  gross: result.grossEarnings,
  epf: result.epfEmployee,
  pt: result.professionalTax,
  tds: result.tds,
  net: result.netPay,
});
