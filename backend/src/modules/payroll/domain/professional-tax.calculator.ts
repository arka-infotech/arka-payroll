/**
 * Karnataka Professional Tax slabs (Bengaluru default for Arka Infotech).
 * Source: Karnataka Tax on Professions, Trades, Callings and Employments Act.
 *
 * Monthly gross salary:
 *   ≤ ₹14,999  → ₹0
 *   ≥ ₹15,000  → ₹200 (₹300 in February for annual reconciliation in some years)
 */
export function calculateKarnatakaProfessionalTax(
  monthlyGross: number,
  month: number,
): number {
  if (monthlyGross < 15_000) {
    return 0;
  }
  // February surcharge commonly applied for annual PT of ₹2,500
  if (month === 2) {
    return 300;
  }
  return 200;
}
