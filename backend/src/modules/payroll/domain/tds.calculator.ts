import { round2 } from './money.util';

/**
 * Simplified monthly TDS estimate under the New Tax Regime (FY 2025-26 style slabs).
 * Production systems should replace this with Form-16 / projected YTD computation
 * including exemptions, standard deduction, and employer-declared investments.
 *
 * New regime illustrative slabs (taxable income after std. deduction):
 *   0 – 3L        : Nil
 *   3L – 7L       : 5%
 *   7L – 10L      : 10%
 *   10L – 12L     : 15%
 *   12L – 15L     : 20%
 *   > 15L         : 30%
 *
 * Rebate u/s 87A assumed for taxable ≤ 7L → tax = 0 (new regime).
 */
export function estimateMonthlyTdsNewRegime(
  projectedAnnualTaxableIncome: number,
): number {
  const stdDeduction = 75_000;
  const taxable = Math.max(0, projectedAnnualTaxableIncome - stdDeduction);

  let annualTax = computeSlabTax(taxable);

  // Section 87A rebate (new regime): full rebate if taxable ≤ 7L
  if (taxable <= 700_000) {
    annualTax = 0;
  }

  // Health & Education Cess 4%
  annualTax = round2(annualTax * 1.04);

  return round2(annualTax / 12);
}

function computeSlabTax(taxable: number): number {
  let tax = 0;
  let remaining = taxable;

  const slabs: Array<{ upTo: number; rate: number }> = [
    { upTo: 300_000, rate: 0 },
    { upTo: 700_000, rate: 0.05 },
    { upTo: 1_000_000, rate: 0.1 },
    { upTo: 1_200_000, rate: 0.15 },
    { upTo: 1_500_000, rate: 0.2 },
    { upTo: Number.POSITIVE_INFINITY, rate: 0.3 },
  ];

  let lower = 0;
  for (const slab of slabs) {
    const band = Math.min(remaining, slab.upTo - lower);
    if (band <= 0) break;
    tax += band * slab.rate;
    remaining -= band;
    lower = slab.upTo;
  }

  return round2(tax);
}
