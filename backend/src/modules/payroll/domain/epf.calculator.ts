import { round2 } from './money.util';

/** Statutory EPF wage ceiling (INR / month). */
export const EPF_WAGE_CEILING = 15_000;
export const EPF_EMPLOYEE_RATE = 0.12;

/**
 * Employee EPF contribution = 12% of PF wages.
 * PF wages = min(Basic + DA, ₹15,000) when ceiling applies,
 * or actual Basic+DA when employer opts for higher wages on actuals.
 *
 * @param basicEarned Prorated basic for the month
 * @param useActuals  If true, contribute on full basic (no ceiling)
 */
export function calculateEmployeeEpf(
  basicEarned: number,
  useActuals = false,
): number {
  const pfWages = useActuals
    ? basicEarned
    : Math.min(basicEarned, EPF_WAGE_CEILING);
  return round2(pfWages * EPF_EMPLOYEE_RATE);
}
