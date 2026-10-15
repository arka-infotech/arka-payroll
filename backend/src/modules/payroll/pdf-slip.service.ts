import { existsSync } from 'fs';
import { Injectable, OnModuleDestroy, ServiceUnavailableException } from '@nestjs/common';
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
  esicEmployee?: { toString(): string } | number | null;
  professionalTax: { toString(): string } | number;
  tds: { toString(): string } | number;
  otherDeductions: { toString(): string } | number;
  totalDeductions: { toString(): string } | number;
  netPay: { toString(): string } | number;
  slipNotes?: string | null;
  status?: string;
  payDate?: Date | string | null;
  slipDocument?: unknown;
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

type SlipLine = { label: string; amount: number };
type SlipDocument = {
  employeeName?: string;
  employeeCode?: string;
  payDate?: string;
  paidDays?: number;
  lopDays?: number;
  notes?: string;
  earnings?: SlipLine[];
  deductions?: SlipLine[];
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

  private resolveChromePath(): string | undefined {
    const candidates = [
      process.env.PUPPETEER_EXECUTABLE_PATH,
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
      '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
      '/Applications/Chromium.app/Contents/MacOS/Chromium',
      '/usr/bin/google-chrome',
      '/usr/bin/chromium',
      '/usr/bin/chromium-browser',
    ].filter((p): p is string => !!p && p.length > 0);

    return candidates.find((p) => existsSync(p));
  }

  private async getBrowser(): Promise<puppeteer.Browser> {
    if (!this.browser || !this.browser.connected) {
      const executablePath = this.resolveChromePath();
      if (!executablePath) {
        throw new ServiceUnavailableException(
          'PDF engine is unavailable. Install Google Chrome or Brave, or set PUPPETEER_EXECUTABLE_PATH.',
        );
      }
      try {
        this.browser = await puppeteer.launch({
          headless: true,
          executablePath,
          args: ['--no-sandbox', '--disable-setuid-sandbox'],
        });
      } catch (err) {
        const detail = err instanceof Error ? err.message : String(err);
        throw new ServiceUnavailableException(
          `PDF engine failed to start (${detail})`,
        );
      }
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

  private defaultLines(slip: SlipRow): { earnings: SlipLine[]; deductions: SlipLine[] } {
    const earn: SlipLine[] = [
      { label: 'Basic', amount: toNumber(slip.basicEarned) },
      { label: 'House Rent Allowance', amount: toNumber(slip.hraEarned) },
      { label: 'Travel allowance', amount: toNumber(slip.conveyanceEarned) },
    ];
    const special = toNumber(slip.specialAllowanceEarned);
    const medical = toNumber(slip.medicalEarned);
    const bonus = toNumber(slip.bonus);
    const other = toNumber(slip.otherEarnings) + toNumber(slip.specialAdjustment);
    if (special) earn.push({ label: 'Special Allowance', amount: special });
    if (medical) earn.push({ label: 'Other Allowance', amount: medical });
    if (bonus) earn.push({ label: 'Bonus', amount: bonus });
    if (other) earn.push({ label: 'Other Earnings', amount: other });

    const ded: SlipLine[] = [
      { label: 'Income Tax', amount: toNumber(slip.tds) },
      { label: 'Provident Fund', amount: toNumber(slip.epfEmployee) },
    ];
    const esic = toNumber(slip.esicEmployee ?? 0);
    const pt = toNumber(slip.professionalTax);
    const otherDed = toNumber(slip.otherDeductions);
    if (esic) ded.push({ label: 'ESIC', amount: esic });
    if (pt) ded.push({ label: 'Professional Tax', amount: pt });
    if (otherDed) ded.push({ label: 'Other Deductions', amount: otherDed });
    return { earnings: earn, deductions: ded };
  }

  private buildHtml(slip: SlipRow): string {
    const company = this.config.get<string>(
      'COMPANY_NAME',
      'Arka Infotech Software Solutions LLP',
    );
    const country = this.config.get<string>('COMPANY_COUNTRY', 'India');
    const doc = asSlipDocument(slip.slipDocument);
    const defaults = this.defaultLines(slip);
    const earnings = (doc?.earnings?.length ? doc.earnings : defaults.earnings).filter(
      (l) => l.label.trim().length > 0,
    );
    const deductions = (doc?.deductions?.length ? doc.deductions : defaults.deductions).filter(
      (l) => l.label.trim().length > 0,
    );
    const gross = earnings.reduce((s, l) => s + toNumber(l.amount), 0);
    const totalDed = deductions.reduce((s, l) => s + toNumber(l.amount), 0);
    const net = doc?.earnings?.length ? gross - totalDed : toNumber(slip.netPay);
    const period = `${MONTH_NAMES[slip.month]} ${slip.year}`;
    const u = slip.user;
    const employeeName = doc?.employeeName?.trim() || `${u.firstName} ${u.lastName}`;
    const employeeCode = doc?.employeeCode?.trim() || u.employeeCode || '—';
    const paidDays = doc?.paidDays ?? slip.daysPayable;
    const lopDays = doc?.lopDays ?? slip.unpaidLeaveDays;
    const payDate = formatPayDate(doc?.payDate ?? slip.payDate);
    const notes = doc?.notes ?? slip.slipNotes ?? '';
    const rows = Math.max(earnings.length, deductions.length, 1);
    const bodyRows = Array.from({ length: rows }, (_, i) => {
      const e = earnings[i];
      const d = deductions[i];
      return `<tr>
        <td>${e ? escapeHtml(e.label) : ''}</td>
        <td class="num">${e ? this.inr(e.amount) : ''}</td>
        <td>${d ? escapeHtml(d.label) : ''}</td>
        <td class="num">${d ? this.inr(d.amount) : ''}</td>
      </tr>`;
    }).join('');

    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<title>Payslip ${escapeHtml(period)}</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: Helvetica, Arial, sans-serif; color: #1c2430; font-size: 11px; }
  .company { font-size: 18px; font-weight: 700; }
  .muted { color: #5c6b7a; margin-top: 2px; }
  .month-label { margin-top: 14px; font-size: 12px; color: #5c6b7a; }
  .month { font-size: 16px; font-weight: 700; margin-top: 2px; }
  .summary { width: 100%; border: 1px solid #e6ebf1; border-radius: 8px; margin-top: 16px; border-collapse: separate; overflow: hidden; }
  .summary td { padding: 10px 14px; vertical-align: top; }
  .k { color: #667085; font-size: 10px; }
  .v { font-weight: 700; margin-top: 2px; }
  .netbox { background: #e8f7f4; text-align: right; width: 34%; }
  .net-k { color: #0f766e; font-size: 10px; font-weight: 700; letter-spacing: 0.04em; }
  .net-v { font-size: 20px; font-weight: 800; color: #0f766e; margin-top: 4px; }
  .days { margin-top: 8px; color: #344054; }
  table.grid { width: 100%; border-collapse: collapse; margin-top: 18px; }
  table.grid th { text-align: left; font-size: 10px; letter-spacing: 0.04em; color: #667085; border-bottom: 1px solid #eaecf0; padding: 8px 6px; }
  table.grid td { padding: 7px 6px; border-bottom: 1px solid #f2f4f7; }
  td.num, th.num { text-align: right; }
  .totals { margin-top: 8px; width: 100%; }
  .totals td { padding: 8px 6px; font-weight: 700; }
  .payable { margin-top: 12px; background: #0f766e; color: white; border-radius: 6px; padding: 12px 14px; display: flex; }
  .payable table { width: 100%; color: white; }
  .payable .big { font-size: 16px; font-weight: 800; text-align: right; }
  .words { margin-top: 10px; font-size: 11px; }
  table.stamps { width: 100%; margin-top: 22px; border-collapse: separate; border-spacing: 14px 0; }
  .stamp-label { font-size: 10px; font-weight: 700; color: #0f766e; margin-bottom: 6px; }
  .stamp-box { height: 78px; border: 1.5px dashed #0f766e; border-radius: 6px; }
  .stamp-hint { margin-top: 4px; font-size: 9px; color: #667085; }
  .foot { margin-top: 18px; text-align: center; color: #98a2b3; font-size: 10px; }
</style>
</head>
<body>
  <div class="company">${escapeHtml(company)}</div>
  <div class="muted">${escapeHtml(country)}</div>
  <div class="month-label">Payslip For the Month</div>
  <div class="month">${escapeHtml(period)}</div>

  <table class="summary">
    <tr>
      <td>
        <div style="font-size:11px;font-weight:800;letter-spacing:.04em;margin-bottom:8px;">EMPLOYEE SUMMARY</div>
        <div class="k">Employee Name</div><div class="v">${escapeHtml(employeeName)}</div>
        <div class="k" style="margin-top:8px;">Employee ID</div><div class="v">${escapeHtml(employeeCode)}</div>
        <div class="k" style="margin-top:8px;">Pay Period</div><div class="v">${escapeHtml(period)}</div>
        <div class="k" style="margin-top:8px;">Pay Date</div><div class="v">${escapeHtml(String(payDate))}</div>
      </td>
      <td class="netbox">
        <div class="net-k">Total Net Pay</div>
        <div class="net-v">${this.inr(net)}</div>
        <div class="days"><strong>Paid Days</strong> ${paidDays}</div>
        <div class="days"><strong>LOP Days</strong> ${lopDays}</div>
      </td>
    </tr>
  </table>

  <table class="grid">
    <thead>
      <tr>
        <th>EARNINGS</th><th class="num">AMOUNT</th>
        <th>DEDUCTIONS</th><th class="num">AMOUNT</th>
      </tr>
    </thead>
    <tbody>${bodyRows}</tbody>
  </table>
  <table class="totals">
    <tr>
      <td>Gross Earnings</td><td class="num">${this.inr(gross)}</td>
      <td>Total Deductions</td><td class="num">${this.inr(totalDed)}</td>
    </tr>
  </table>

  <div class="payable">
    <table><tr>
      <td>
        <div style="font-weight:800;letter-spacing:.03em;">TOTAL NET PAYABLE</div>
        <div style="font-size:10px;opacity:.9;margin-top:2px;">Gross Earnings − Total Deductions</div>
      </td>
      <td class="big">${this.inr(net)}</td>
    </tr></table>
  </div>
  <div class="words"><strong>Amount in words:</strong> ${escapeHtml(inrWords(net))}</div>
  ${notes.trim() ? `<div class="words"><strong>Notes:</strong> ${escapeHtml(notes.trim())}</div>` : ''}

  <table class="stamps">
    <tr>
      <td>
        <div class="stamp-label">Employer stamp &amp; authorised signatory</div>
        <div class="stamp-box"></div>
        <div class="stamp-hint">Affix company stamp and sign</div>
      </td>
      <td>
        <div class="stamp-label">Employee acknowledgement</div>
        <div class="stamp-box"></div>
        <div class="stamp-hint">Signature</div>
      </td>
    </tr>
  </table>
  <div class="foot">— This is a system-generated document. —</div>
</body>
</html>`;
  }
}


function formatPayDate(value: string | Date | null | undefined): string {
  if (!value) return '—';
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toLocaleDateString('en-GB');
}

function asSlipDocument(value: unknown): SlipDocument | undefined {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return undefined;
  return value as SlipDocument;
}

function inrWords(amount: number): string {
  const n = Math.round(Math.abs(amount));
  if (n === 0) return 'Indian Rupee Zero Only';
  const ones = ['','One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Ten','Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen','Seventeen','Eighteen','Nineteen'];
  const tens = ['','','Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'];
  const two = (num: number): string => {
    if (num < 20) return ones[num];
    return `${tens[Math.floor(num / 10)]}${num % 10 ? ' ' + ones[num % 10] : ''}`.trim();
  };
  const parts: string[] = [];
  const crore = Math.floor(n / 10000000);
  const lakh = Math.floor((n % 10000000) / 100000);
  const thousand = Math.floor((n % 100000) / 1000);
  const hundred = Math.floor((n % 1000) / 100);
  const rest = n % 100;
  if (crore) parts.push(`${two(crore)} Crore`);
  if (lakh) parts.push(`${two(lakh)} Lakh`);
  if (thousand) parts.push(`${two(thousand)} Thousand`);
  if (hundred) parts.push(`${ones[hundred]} Hundred`);
  if (rest) parts.push(two(rest));
  const paise = Math.round((Math.abs(amount) - Math.floor(Math.abs(amount))) * 100);
  const tail = paise ? ` and ${two(paise)} Paise` : '';
  return `Indian Rupee ${parts.join(' ')}${tail} Only`;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
