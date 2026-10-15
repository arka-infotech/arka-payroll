/**
 * Maharashtra Professional Tax (PT) — mandatory for salaried employees.
 * Official monthly slabs (startup / MSME payroll, FY 2025-26 style):
 *
 *   Gross ≤ ₹7,500           → ₹0
 *   Gross ₹7,501 – ₹10,000   → ₹175
 *   Gross > ₹10,000          → ₹200
 *     except March (month 3) → ₹300  (annual cap reconciliation → ₹2,500)
 */
export function calculateMaharashtraProfessionalTax(
  monthlyGross: number,
  month: number,
): number {
  if (monthlyGross <= 7_500) {
    return 0;
  }
  if (monthlyGross <= 10_000) {
    return 175;
  }
  // March auto-trigger — HR does not need to remember this
  if (month === 3) {
    return 300;
  }
  return 200;
}

/** @deprecated Use calculateMaharashtraProfessionalTax — kept for import safety. */
export const calculateKarnatakaProfessionalTax =
  calculateMaharashtraProfessionalTax;
