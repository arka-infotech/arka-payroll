import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as puppeteer from 'puppeteer';
import { toNumber } from './domain/money.util';

type SlipRow = {
  year: number;
  month: number;
  trackingReference: string;
  workingDaysInMonth: number;
  daysPayable: number;
  unpaidLeaveDays: number;
  basicEarned: { toString(): string } | number;
  hraEarned: { toString(): string } | number;
  specialAllowanceEarned: { toString(): string } | number;
  conveyanceEarned: { toString(): string } | number;
  medicalEarned: { toString(): string } | number;
  bonus: { toString(): string } | number;
  specialAdjustment: { toString(): string } | number;
  otherEarnings: { toString(): string } | number;
  grossEarnings: { toString(): string } | number;
  epfEmployee: { toString(): string } | number;
  professionalTax: { toString(): string } | number;
  tds: { toString(): string } | number;
  otherDeductions: { toString(): string } | number;
  totalDeductions: { toString(): string } | number;
  netPay: { toString(): string } | number;
  user: {
    firstName: string;
    lastName: string;
    employeeCode: string | null;
    designation: string | null;
    dateOfJoining: Date | null;
    pan: string | null;
    uan: string | null;
    bankName: string | null;
    bankAccountNumber: string | null;
    bankIfsc: string | null;
    email: string;
  };
};

const MONTH_NAMES = [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

@Injectable()
export class PdfSlipService implements OnModuleDestroy {
  private browser: puppeteer.Browser | null = null;

  constructor(private readonly config: ConfigService) {}

  async onModuleDestroy(): Promise<void> {
    if (this.browser) {
      await this.browser.close();
      this.browser = null;
    }
  }

  private async getBrowser(): Promise<puppeteer.Browser> {
    if (!this.browser || !this.browser.connected) {
      this.browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox'],
      });
    }
    return this.browser;
  }

  /** Renders an industrial A4 salary slip PDF via Puppeteer. */
  async renderA4(slip: SlipRow): Promise<Buffer> {
    const html = this.buildHtml(slip);
    const browser = await this.getBrowser();
    const page = await browser.newPage();
    try {
      await page.setContent(html, { waitUntil: 'networkidle0' });
      const pdf = await page.pdf({
        format: 'A4',
        printBackground: true,
        margin: { top: '12mm', right: '12mm', bottom: '12mm', left: '12mm' },
      });
      return Buffer.from(pdf);
    } finally {
      await page.close();
    }
  }

  private inr(n: { toString(): string } | number): string {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      minimumFractionDigits: 2,
    }).format(toNumber(n));
  }

  private maskAccount(acct: string | null): string {
    if (!acct || acct.length < 4) return acct ?? '—';
    return `${'*'.repeat(Math.max(0, acct.length - 4))}${acct.slice(-4)}`;
  }

  private buildHtml(slip: SlipRow): string {
    const company = this.config.get<string>(
      'COMPANY_NAME',
      'Arka Infotech Software Solutions LLP',
    );
    const address = this.config.get<string>(
      'COMPANY_ADDRESS',
      'Bengaluru, Karnataka, India',
    );
    const period = `${MONTH_NAMES[slip.month]} ${slip.year}`;
    const u = slip.user;
    const doj = u.dateOfJoining
      ? new Date(u.dateOfJoining).toLocaleDateString('en-IN')
      : '—';

    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<title>Salary Slip — ${slip.trackingReference}</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Segoe UI', Helvetica, Arial, sans-serif; color: #1a1a1a; font-size: 11px; }
  .sheet { width: 100%; }
  .header { border-bottom: 2px solid #0b3d5c; padding-bottom: 10px; margin-bottom: 14px; }
  .company { font-size: 18px; font-weight: 700; color: #0b3d5c; }
  .sub { color: #555; margin-top: 2px; }
  .title { text-align: center; font-size: 14px; font-weight: 600; margin: 12px 0; letter-spacing: 0.04em; }
  .meta { width: 100%; border-collapse: collapse; margin-bottom: 12px; }
  .meta td { padding: 4px 6px; vertical-align: top; width: 50%; }
  .label { color: #666; }
  table.pay { width: 100%; border-collapse: collapse; margin-top: 8px; }
  table.pay th, table.pay td { border: 1px solid #ccc; padding: 6px 8px; }
  table.pay th { background: #eef4f8; text-align: left; }
  table.pay td.num { text-align: right; font-variant-numeric: tabular-nums; }
  .totals td { font-weight: 700; background: #f7fafc; }
  .net { font-size: 13px; margin-top: 12px; padding: 8px; background: #0b3d5c; color: #fff; border-radius: 4px; }
  .disclaimer { margin-top: 28px; text-align: center; font-size: 10px; color: #666; border-top: 1px dashed #bbb; padding-top: 10px; font-style: italic; }
  .ref { font-family: ui-monospace, monospace; font-size: 10px; color: #444; }
</style>
</head>
<body>
  <div class="sheet">
    <div class="header">
      <div class="company">${escapeHtml(company)}</div>
      <div class="sub">${escapeHtml(address)}</div>
      <div class="sub ref">Ref: ${escapeHtml(slip.trackingReference)}</div>
    </div>

    <div class="title">SALARY SLIP — ${escapeHtml(period)}</div>

    <table class="meta">
      <tr>
        <td><span class="label">Employee</span><br/><strong>${escapeHtml(u.firstName)} ${escapeHtml(u.lastName)}</strong></td>
        <td><span class="label">Employee Code</span><br/><strong>${escapeHtml(u.employeeCode ?? '—')}</strong></td>
      </tr>
      <tr>
        <td><span class="label">Designation</span><br/>${escapeHtml(u.designation ?? '—')}</td>
        <td><span class="label">Date of Joining</span><br/>${escapeHtml(doj)}</td>
      </tr>
      <tr>
        <td><span class="label">PAN</span><br/>${escapeHtml(u.pan ?? '—')}</td>
        <td><span class="label">UAN</span><br/>${escapeHtml(u.uan ?? '—')}</td>
      </tr>
      <tr>
        <td><span class="label">Bank</span><br/>${escapeHtml(u.bankName ?? '—')} / ${escapeHtml(this.maskAccount(u.bankAccountNumber))}</td>
        <td><span class="label">IFSC</span><br/>${escapeHtml(u.bankIfsc ?? '—')}</td>
      </tr>
      <tr>
        <td><span class="label">Working Days</span><br/>${slip.workingDaysInMonth}</td>
        <td><span class="label">Days Payable / LOP</span><br/>${slip.daysPayable} / ${slip.unpaidLeaveDays}</td>
      </tr>
    </table>

    <table class="pay">
      <thead>
        <tr>
          <th style="width:50%">Earnings</th>
          <th style="width:50%">Deductions</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>
            <table style="width:100%;border:none">
              <tr><td>Basic</td><td class="num">${this.inr(slip.basicEarned)}</td></tr>
              <tr><td>HRA</td><td class="num">${this.inr(slip.hraEarned)}</td></tr>
              <tr><td>Special Allowance</td><td class="num">${this.inr(slip.specialAllowanceEarned)}</td></tr>
              <tr><td>Conveyance</td><td class="num">${this.inr(slip.conveyanceEarned)}</td></tr>
              <tr><td>Medical</td><td class="num">${this.inr(slip.medicalEarned)}</td></tr>
              <tr><td>Bonus</td><td class="num">${this.inr(slip.bonus)}</td></tr>
              <tr><td>Special Adjustment</td><td class="num">${this.inr(slip.specialAdjustment)}</td></tr>
              <tr><td>Other Earnings</td><td class="num">${this.inr(slip.otherEarnings)}</td></tr>
            </table>
          </td>
          <td>
            <table style="width:100%;border:none">
              <tr><td>EPF (Employee)</td><td class="num">${this.inr(slip.epfEmployee)}</td></tr>
              <tr><td>Professional Tax</td><td class="num">${this.inr(slip.professionalTax)}</td></tr>
              <tr><td>Income Tax (TDS)</td><td class="num">${this.inr(slip.tds)}</td></tr>
              <tr><td>Other Deductions</td><td class="num">${this.inr(slip.otherDeductions)}</td></tr>
            </table>
          </td>
        </tr>
        <tr class="totals">
          <td>Gross Earnings: ${this.inr(slip.grossEarnings)}</td>
          <td>Total Deductions: ${this.inr(slip.totalDeductions)}</td>
        </tr>
      </tbody>
    </table>

    <div class="net">Net Pay: ${this.inr(slip.netPay)}</div>

    <div class="disclaimer">
      This is a computer-generated document and requires no physical signature.
    </div>
  </div>
</body>
</html>`;
  }
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
