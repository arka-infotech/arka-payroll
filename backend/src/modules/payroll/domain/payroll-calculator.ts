import { calculateEmployeeEpf } from './epf.calculator';
import { calculateMaharashtraProfessionalTax } from './professional-tax.calculator';
import { estimateMonthlyTdsNewRegime } from './tds.calculator';
import { prorate, round2, toNumber } from './money.util';

export interface SalaryStructureInput {
  annualCtc: number | { toString(): string };
  basicMonthly: number | { toString(): string };
  hraMonthly: number | { toString(): string };
  specialAllowanceMonthly: number | { toString(): string };
  conveyanceMonthly: number | { toString(): string };
  medicalMonthly: number | { toString(): string };
  /** Startup default: false (< 20 employees — EPF optional). */
  epfApplicable: boolean;
  /** Startup default: false (< 10 employees — ESIC N/A). */
  esicApplicable?: boolean;
  taxRegime: string;
  professionalTaxApplicable?: boolean;
  tdsApplicable?: boolean;
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
  /** Explicit ₹0 when not applicable — kept for bank/visa genuineness. */
  epfEmployee: number;
  esicEmployee: number;
  professionalTax: number;
  tds: number;
  otherDeductions: number;
  totalDeductions: number;
  netPay: number;
  lopDeductionEstimate: number;
  snapshot: Record<string, unknown>;
}

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

  const monthlyFixed = round2(basic + hra + special + conveyance + medical);
  const lopDeductionEstimate =
    workingDays > 0 ? round2((monthlyFixed * unpaid) / workingDays) : 0;

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

  // < 20 employees: EPF optional — default off → explicit ₹0.00 on slip
  const epfEmployee = structure.epfApplicable
    ? calculateEmployeeEpf(basicEarned, vars.epfOnActuals ?? false)
    : 0;

  // < 10 employees: ESIC N/A — keep column, always ₹0 until enabled
  const esicEmployee = structure.esicApplicable ? 0 : 0;

  const professionalTax = structure.professionalTaxApplicable
    ? calculateMaharashtraProfessionalTax(grossEarnings, vars.month)
    : 0;

  const projectedAnnual = toNumber(structure.annualCtc);
  const tds = structure.tdsApplicable
    ? estimateMonthlyTdsNewRegime(projectedAnnual)
    : 0;

  const otherDeductions = round2(vars.otherDeductions);
  const totalDeductions = round2(
    epfEmployee + esicEmployee + professionalTax + tds + otherDeductions,
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
    esicEmployee,
    professionalTax,
    tds,
    otherDeductions,
    totalDeductions,
    netPay,
    lopDeductionEstimate,
    snapshot: {
      engine: 'aips-payroll-mh-v1',
      state: 'Maharashtra',
      structure: {
        annualCtc: projectedAnnual,
        basic,
        hra,
        special,
        conveyance,
        medical,
        epfApplicable: structure.epfApplicable,
        esicApplicable: structure.esicApplicable ?? false,
        taxRegime: structure.taxRegime,
      },
      variables: vars,
      lopDeductionEstimate,
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
  const code = sanitizeEmpCode(employeeCode) || userId.slice(0, 8).toUpperCase();
  return `AIPS-${year}-${mm}-${code}`;
}

/** Download / email filename — always prefers the employee's current Emp ID. */
export function payslipFilename(input: {
  year: number;
  month: number;
  trackingReference: string;
  employeeCode?: string | null;
  slipDocument?: unknown;
}): string {
  const doc =
    input.slipDocument &&
    typeof input.slipDocument === 'object' &&
    !Array.isArray(input.slipDocument)
      ? (input.slipDocument as Record<string, unknown>)
      : undefined;
  const fromDoc =
    typeof doc?.employeeCode === 'string' ? doc.employeeCode.trim() : '';
  const code = sanitizeEmpCode(fromDoc || input.employeeCode);
  if (code) {
    const mm = String(input.month).padStart(2, '0');
    return `AIPS-${input.year}-${mm}-${code}.pdf`;
  }
  const ref = input.trackingReference.trim() || 'salary-slip';
  return ref.toLowerCase().endsWith('.pdf') ? ref : `${ref}.pdf`;
}

function sanitizeEmpCode(value: string | null | undefined): string {
  const raw = (value ?? '').trim();
  if (!raw) return '';
  return raw.replace(/[^\w.-]+/g, '_').toUpperCase();
}

/** Calendar days in a month (for Days Worked validation). */
export function daysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate();
}
