import { calculateEmployeeEpf } from './epf.calculator';
import { calculateKarnatakaProfessionalTax } from './professional-tax.calculator';
import { estimateMonthlyTdsNewRegime } from './tds.calculator';
import { prorate, round2, toNumber } from './money.util';

export interface SalaryStructureInput {
  annualCtc: number | { toString(): string };
  basicMonthly: number | { toString(): string };
  hraMonthly: number | { toString(): string };
  specialAllowanceMonthly: number | { toString(): string };
  conveyanceMonthly: number | { toString(): string };
  medicalMonthly: number | { toString(): string };
  epfApplicable: boolean;
  taxRegime: string;
}

export interface MonthlyVariablesInput {
  year: number;
  month: number;
  workingDaysInMonth: number;
  unpaidLeaveDays: number;
  bonus: number;
  specialAdjustment: number;
  otherEarnings: number;
  otherDeductions: number;
  /** When true, EPF on actual basic (no ₹15k ceiling). */
  epfOnActuals?: boolean;
}

export interface PayrollComputationResult {
  daysPayable: number;
  basicEarned: number;
  hraEarned: number;
  specialAllowanceEarned: number;
  conveyanceEarned: number;
  medicalEarned: number;
  bonus: number;
  specialAdjustment: number;
  otherEarnings: number;
  grossEarnings: number;
  epfEmployee: number;
  professionalTax: number;
  tds: number;
  otherDeductions: number;
  totalDeductions: number;
  netPay: number;
  snapshot: Record<string, unknown>;
}

/**
 * Pure computation — no I/O. Safe to unit-test in isolation.
 */
export function computeMonthlyPayroll(
  structure: SalaryStructureInput,
  vars: MonthlyVariablesInput,
): PayrollComputationResult {
  const workingDays = vars.workingDaysInMonth;
  const unpaid = Math.max(0, vars.unpaidLeaveDays);
  const daysPayable = Math.max(0, workingDays - unpaid);

  const basic = toNumber(structure.basicMonthly);
  const hra = toNumber(structure.hraMonthly);
  const special = toNumber(structure.specialAllowanceMonthly);
  const conveyance = toNumber(structure.conveyanceMonthly);
  const medical = toNumber(structure.medicalMonthly);

  const basicEarned = prorate(basic, daysPayable, workingDays);
  const hraEarned = prorate(hra, daysPayable, workingDays);
  const specialAllowanceEarned = prorate(special, daysPayable, workingDays);
  const conveyanceEarned = prorate(conveyance, daysPayable, workingDays);
  const medicalEarned = prorate(medical, daysPayable, workingDays);

  const bonus = round2(vars.bonus);
  const specialAdjustment = round2(vars.specialAdjustment);
  const otherEarnings = round2(vars.otherEarnings);

  const grossEarnings = round2(
    basicEarned +
      hraEarned +
      specialAllowanceEarned +
      conveyanceEarned +
      medicalEarned +
      bonus +
      specialAdjustment +
      otherEarnings,
  );

  const epfEmployee = structure.epfApplicable
    ? calculateEmployeeEpf(basicEarned, vars.epfOnActuals ?? false)
    : 0;

  const professionalTax = calculateKarnatakaProfessionalTax(
    grossEarnings,
    vars.month,
  );

  // Project annual taxable ≈ annual CTC − employer statutorys (simplified)
  const projectedAnnual = toNumber(structure.annualCtc);
  const tds =
    structure.taxRegime === 'OLD'
      ? estimateMonthlyTdsNewRegime(projectedAnnual) // swap for Old-regime engine in production
      : estimateMonthlyTdsNewRegime(projectedAnnual);

  const otherDeductions = round2(vars.otherDeductions);
  const totalDeductions = round2(
    epfEmployee + professionalTax + tds + otherDeductions,
  );
  const netPay = round2(grossEarnings - totalDeductions);

  return {
    daysPayable,
    basicEarned,
    hraEarned,
    specialAllowanceEarned,
    conveyanceEarned,
    medicalEarned,
    bonus,
    specialAdjustment,
    otherEarnings,
    grossEarnings,
    epfEmployee,
    professionalTax,
    tds,
    otherDeductions,
    totalDeductions,
    netPay,
    snapshot: {
      engine: 'arka-payroll-v1',
      structure: {
        annualCtc: projectedAnnual,
        basic,
        hra,
        special,
        conveyance,
        medical,
        epfApplicable: structure.epfApplicable,
        taxRegime: structure.taxRegime,
      },
      variables: vars,
      computedAt: new Date().toISOString(),
    },
  };
}

export function buildTrackingReference(
  year: number,
  month: number,
  employeeCode: string | null | undefined,
  userId: string,
): string {
  const mm = String(month).padStart(2, '0');
  const code = (employeeCode ?? userId.slice(0, 8)).toUpperCase();
  return `ARKA-${year}-${mm}-${code}`;
}
