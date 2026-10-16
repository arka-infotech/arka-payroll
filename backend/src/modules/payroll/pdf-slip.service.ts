import { existsSync, readFileSync } from 'fs';
import { join } from 'path';
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
  companyName?: string;
  location?: string;
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
  private logoDataUri: string | null = null;

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
        displayHeaderFooter: true,
        headerTemplate: '<div></div>',
        footerTemplate: this.footerTemplate(),
        margin: { top: '12mm', right: '14mm', bottom: '18mm', left: '14mm' },
      });
      return Buffer.from(pdf);
    } finally {
      await page.close();
    }
  }

  private inr(n: { toString(): string } | number): string {
    const formatted = new Intl.NumberFormat('en-IN', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(toNumber(n));
    return `₹${formatted}`;
  }

  private footerTemplate(): string {
    const logo = this.logoSrc();
    const mark = logo
      ? `<img src="${logo}" style="width:14px;height:14px;vertical-align:middle;margin-right:6px;"/>`
      : '';
    return `<div style="width:100%;font-size:10px;text-align:center;color:#98a2b3;font-family:Helvetica,Arial,sans-serif;padding:0 12mm;">${mark}Powered by <span style="color:#14808f;font-weight:700;">Arka Payroll</span></div>`;
  }

  private logoSrc(): string {
    if (this.logoDataUri !== null) return this.logoDataUri;
    const file = [
      join(process.cwd(), 'assets/payslip-logo.png'),
      join(process.cwd(), 'backend/assets/payslip-logo.png'),
    ].find((path) => existsSync(path));
    this.logoDataUri = file
      ? `data:image/png;base64,${readFileSync(file).toString('base64')}`
      : '';
    return this.logoDataUri;
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
    const doc = asSlipDocument(slip.slipDocument);
    const company =
      doc?.companyName?.trim() ||
      this.config.get<string>(
        'COMPANY_NAME',
        'Arka Infotech Software Solutions',
      );
    const location =
      doc?.location?.trim() ||
      this.config.get<string>(
        'COMPANY_ADDRESS',
        'Office .no 512, Suchita Business Park, Patel chowk, opposite Hanuman temple, Shival Nagar, Saibaba Nagar, Pant Nagar, Ghatkopar East, Mumbai, Maharashtra 400077',
      );
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

    const logo = this.logoSrc();
    const logoHtml = logo
      ? `<div class="logo"><img src="${logo}" alt=""/></div>`
      : '';

    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<title>Payslip ${escapeHtml(period)}</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: Helvetica, Arial, sans-serif; color: #1f2430; font-size: 12px; background: #fff; }
  table { border-collapse: collapse; }
  .top { width: 100%; }
  .top td { vertical-align: middle; }
  .brand { display: flex; align-items: center; }
  .logo { width: 58px; height: 58px; margin-right: 12px; background: transparent; border: none; padding: 0; }
  .logo img { width: 100%; height: 100%; object-fit: contain; background: transparent; }
  .identity { max-width: 440px; }
  .company { font-size: 18px; font-weight: 700; color: #1a1d23; letter-spacing: -0.01em; }
  .location { margin-top: 3px; color: #8b919a; font-size: 11px; line-height: 1.35; }
  .period { text-align: right; }
  .period-k { color: #8b919a; font-size: 12px; }
  .period-v { margin-top: 2px; font-size: 16px; font-weight: 700; color: #1a1d23; }
  .summary { width: 100%; margin-top: 28px; }
  .summary > tbody > tr > td { vertical-align: top; }
  .section-k { color: #8b919a; font-size: 11px; font-weight: 700; letter-spacing: 0.06em; margin-bottom: 12px; }
  table.kv { width: 100%; }
  table.kv td { padding: 5px 0; font-size: 12.5px; }
  table.kv .lk { color: #6b7280; width: 118px; }
  table.kv .colon { color: #9aa1ab; width: 16px; }
  table.kv .lv { color: #1f2430; font-weight: 600; }
  .netwrap { width: 292px; }
  .netcard { width: 292px; border: 1px solid #e6e8ee; border-radius: 10px; overflow: hidden; }
  .net-top { background: #f3fbf6; padding: 16px 16px 12px; }
  .net-amt-row { display: flex; align-items: stretch; gap: 10px; }
  .accent { width: 3px; background: #1f9d55; border-radius: 2px; }
  .net-amt { font-size: 22px; font-weight: 700; color: #1a1d23; line-height: 1.1; }
  .net-sub { margin-top: 3px; color: #6b7280; font-size: 12px; }
  .net-days { padding: 10px 16px 14px; border-top: 1px dotted #d5d9e0; }
  .net-days table { width: 100%; }
  .net-days td { padding: 3px 0; color: #4b5563; font-size: 12.5px; }
  .net-days .c { width: 18px; text-align: center; color: #9aa1ab; }
  .net-days .n { text-align: right; font-weight: 600; color: #1f2430; width: 36px; }
  .panel { width: 100%; margin-top: 22px; border: 1px solid #e6e8ee; border-radius: 10px; overflow: hidden; border-collapse: separate; border-spacing: 0; }
  .panel th { text-align: left; font-size: 11px; font-weight: 700; letter-spacing: 0.05em; color: #8b919a; padding: 12px 14px 8px; border-bottom: 1px dotted #e1e4ea; }
  .panel th.num, .panel td.num { text-align: right; }
  .panel td { padding: 11px 14px; border-bottom: 1px dotted #eceff3; font-size: 12.5px; }
  .panel tr.gross td { background: #f6f7f9; border-bottom: none; font-weight: 700; }
  .payable { width: 100%; margin-top: 16px; border: 1px solid #e6e8ee; border-radius: 10px; overflow: hidden; border-collapse: separate; }
  .payable td { padding: 14px 16px; vertical-align: middle; }
  .payable .title { font-size: 13px; font-weight: 800; letter-spacing: 0.02em; }
  .payable .sub { margin-top: 3px; color: #8b919a; font-size: 11.5px; }
  .payable .amt { width: 28%; background: #f3fbf6; text-align: right; font-size: 15px; font-weight: 700; border-left: 1px solid #e6e8ee; }
  .words { margin-top: 22px; text-align: center; color: #4b5563; font-size: 12px; }
  .rule { margin: 14px 48px 0; border-top: 1px solid #e6e8ee; }
  .foot { margin-top: 22px; text-align: center; color: #b0b6c0; font-size: 12px; }
  .notes { margin-top: 10px; text-align: center; color: #6b7280; font-size: 11.5px; }
</style>
</head>
<body>
  <table class="top">
    <tr>
      <td>
        <table><tr>
          <td>${logoHtml}</td>
          <td>
            <div class="identity">
              <div class="company">${escapeHtml(company)}</div>
              <div class="location">${escapeHtml(location)}</div>
            </div>
          </td>
        </tr></table>
      </td>
      <td class="period">
        <div class="period-k">Payslip For the Month</div>
        <div class="period-v">${escapeHtml(period)}</div>
      </td>
    </tr>
  </table>

  <table class="summary">
    <tr>
      <td>
        <div class="section-k">EMPLOYEE SUMMARY</div>
        <table class="kv">
          <tr><td class="lk">Employee Name</td><td class="colon">:</td><td class="lv">${escapeHtml(employeeName)}</td></tr>
          <tr><td class="lk">Employee ID</td><td class="colon">:</td><td class="lv">${escapeHtml(employeeCode)}</td></tr>
          <tr><td class="lk">Pay Period</td><td class="colon">:</td><td class="lv">${escapeHtml(period)}</td></tr>
          <tr><td class="lk">Pay Date</td><td class="colon">:</td><td class="lv">${escapeHtml(String(payDate))}</td></tr>
        </table>
      </td>
      <td class="netwrap">
        <div class="netcard">
          <div class="net-top">
            <div class="net-amt-row">
              <div class="accent"></div>
              <div>
                <div class="net-amt">${this.inr(net)}</div>
                <div class="net-sub">Total Net Pay</div>
              </div>
            </div>
          </div>
          <div class="net-days">
            <table>
              <tr><td>Paid Days</td><td class="c">:</td><td class="n">${paidDays}</td></tr>
              <tr><td>LOP Days</td><td class="c">:</td><td class="n">${lopDays}</td></tr>
            </table>
          </div>
        </div>
      </td>
    </tr>
  </table>

  <table class="panel">
    <thead>
      <tr>
        <th>EARNINGS</th><th class="num">AMOUNT</th>
        <th>DEDUCTIONS</th><th class="num">AMOUNT</th>
      </tr>
    </thead>
    <tbody>
      ${bodyRows}
      <tr class="gross">
        <td>Gross Earnings</td><td class="num">${this.inr(gross)}</td>
        <td>Total Deductions</td><td class="num">${this.inr(totalDed)}</td>
      </tr>
    </tbody>
  </table>

  <table class="payable">
    <tr>
      <td>
        <div class="title">TOTAL NET PAYABLE</div>
        <div class="sub">Gross Earnings - Total Deductions</div>
      </td>
      <td class="amt">${this.inr(net)}</td>
    </tr>
  </table>

  <div class="words">Amount In Words : ${escapeHtml(inrWords(net))}</div>
  <div class="rule"></div>
  ${notes.trim() ? `<div class="notes">${escapeHtml(notes.trim())}</div>` : ''}
  <div class="foot">-- This is a system-generated document. --</div>
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
    const ten = tens[Math.floor(num / 10)];
    const one = ones[num % 10];
    return one ? `${ten}-${one}` : ten;
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
