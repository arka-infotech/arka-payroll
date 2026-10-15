/**
 * Money helpers — all intermediate payroll math uses 2-decimal INR rounding
 * (banker's-style HALF_UP via Number.toFixed for deterministic slips).
 */

export function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

export function toNumber(value: { toString(): string } | number | string): number {
  return typeof value === 'number' ? value : Number(value.toString());
}

export function prorate(
  monthlyAmount: number,
  daysPayable: number,
  workingDays: number,
): number {
  if (workingDays <= 0) return 0;
  return round2((monthlyAmount * daysPayable) / workingDays);
}
