import { existsSync, readFileSync } from 'fs';
import { join } from 'path';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
// pdfkit is CommonJS; `import PDFDocument from 'pdfkit'` compiles to
// `pdfkit_1.default`, which is undefined at runtime under Nest (no esModuleInterop).
import PDFDocument = require('pdfkit');
import { toNumber } from './domain/money.util';
import {
  formatPayslipMonthLabel,
  formatPayslipPeriodRange,
} from './domain/payroll-calculator';

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
  payPeriod?: string;
  payslipMonth?: string;
  paidDays?: number;
  lopDays?: number;
  notes?: string;
  earnings?: SlipLine[];
  deductions?: SlipLine[];
};

/**
 * A4 payslip PDF via PDFKit (no Chrome / Puppeteer).
 * Amounts use "Rs." so Helvetica stays readable without embedding fonts.
 */
@Injectable()
export class PdfSlipService {
  constructor(private readonly config: ConfigService) {}

  async renderA4(slip: SlipRow): Promise<Buffer> {
    const docJson = asSlipDocument(slip.slipDocument);
    const company =
      docJson?.companyName?.trim() ||
      this.config.get<string>(
        'COMPANY_NAME',
        'Arka Infotech Software Solutions',
      );
    const location =
      docJson?.location?.trim() ||
      this.config.get<string>(
        'COMPANY_ADDRESS',
        'Office .no 512, Suchita Business Park, Patel chowk, opposite Hanuman temple, Shival Nagar, Saibaba Nagar, Pant Nagar, Ghatkopar East, Mumbai, Maharashtra 400077',
      );
    const defaults = this.defaultLines(slip);
    const earnings = (
      docJson?.earnings?.length ? docJson.earnings : defaults.earnings
    ).filter((l) => l.label.trim().length > 0);
    const deductions = (
      docJson?.deductions?.length ? docJson.deductions : defaults.deductions
    ).filter((l) => l.label.trim().length > 0);
    const gross = earnings.reduce((s, l) => s + toNumber(l.amount), 0);
    const totalDed = deductions.reduce((s, l) => s + toNumber(l.amount), 0);
    const net = docJson?.earnings?.length
      ? gross - totalDed
      : toNumber(slip.netPay);
    const monthLabel =
      docJson?.payslipMonth?.trim() ||
      formatPayslipMonthLabel(slip.year, slip.month);
    const periodRange =
      docJson?.payPeriod?.trim() ||
      formatPayslipPeriodRange(slip.year, slip.month);
    const u = slip.user;
    const employeeName =
      docJson?.employeeName?.trim() || `${u.firstName} ${u.lastName}`;
    const employeeCode =
      docJson?.employeeCode?.trim() || u.employeeCode || '-';
    const paidDays = docJson?.paidDays ?? slip.daysPayable;
    const lopDays = docJson?.lopDays ?? slip.unpaidLeaveDays;
    const payDate = formatPayDate(docJson?.payDate ?? slip.payDate);
    const notes = docJson?.notes ?? slip.slipNotes ?? '';

    const logoBuf = loadPayslipLogo();

    return new Promise<Buffer>((resolve, reject) => {
      // bufferPages so we can always pin the footer to page 1 (A4 only).
      const doc = new PDFDocument({
        size: 'A4',
        bufferPages: true,
        autoFirstPage: true,
        margins: { top: 28, bottom: 52, left: 36, right: 36 },
      });
      const chunks: Buffer[] = [];
      doc.on('data', (c: Buffer) => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const left = doc.page.margins.left;
      const pageW = doc.page.width - left - doc.page.margins.right;
      const footerBand = 44;
      const contentBottom = doc.page.height - footerBand - 8;
      let y = doc.page.margins.top;

      const drawLogo = (x: number, atY: number, size: number) => {
        if (!logoBuf) return;
        try {
          doc.image(logoBuf, x, atY, { fit: [size, size] });
        } catch {
          /* ignore logo errors */
        }
      };

      // ── Header (logo + company title) ─────────────────────────────────
      drawLogo(left, y, 40);
      const titleX = left + (logoBuf ? 48 : 0);
      const titleW = pageW - (logoBuf ? 48 : 0) - 150;
      doc
        .font('Helvetica-Bold')
        .fontSize(13)
        .fillColor('#1a1d23')
        .text(company, titleX, y, { width: titleW, lineBreak: false });
      doc
        .font('Helvetica')
        .fontSize(7.5)
        .fillColor('#8b919a')
        .text(location, titleX, y + 16, {
          width: titleW,
          height: 28,
          ellipsis: true,
        });
      doc
        .font('Helvetica')
        .fontSize(8)
        .fillColor('#8b919a')
        .text('Payslip For the Month', left, y, {
          width: pageW,
          align: 'right',
          lineBreak: false,
        });
      doc
        .font('Helvetica-Bold')
        .fontSize(11)
        .fillColor('#1a1d23')
        .text(monthLabel, left, y + 12, {
          width: pageW,
          align: 'right',
          lineBreak: false,
        });

      y += 48;
      doc
        .font('Helvetica-Bold')
        .fontSize(8)
        .fillColor('#8b919a')
        .text('EMPLOYEE SUMMARY', left, y, { lineBreak: false });
      y += 12;

      const summaryTop = y;
      const kv = (label: string, value: string) => {
        doc
          .font('Helvetica')
          .fontSize(8)
          .fillColor('#6b7280')
          .text(label, left, y, { width: 86, lineBreak: false });
        doc
          .fillColor('#9aa1ab')
          .text(':', left + 86, y, { width: 10, lineBreak: false });
        doc
          .font('Helvetica-Bold')
          .fillColor('#1a1d23')
          .text(value, left + 98, y, {
            width: pageW - 300,
            lineBreak: false,
            ellipsis: true,
          });
        y += 12;
      };
      kv('Employee Name', employeeName);
      kv('Employee ID', employeeCode);
      kv('Pay Period', periodRange);
      kv('Pay Date', payDate);

      const cardX = left + pageW - 170;
      const cardY = summaryTop;
      doc.roundedRect(cardX, cardY, 170, 62, 5).strokeColor('#e6e8ee').stroke();
      doc.rect(cardX, cardY, 170, 34).fill('#f3fbf6');
      doc
        .font('Helvetica-Bold')
        .fontSize(12)
        .fillColor('#1a1d23')
        .text(inr(net), cardX + 10, cardY + 8, {
          width: 150,
          lineBreak: false,
        });
      doc
        .font('Helvetica')
        .fontSize(7)
        .fillColor('#6b7280')
        .text('Total Net Pay', cardX + 10, cardY + 22, {
          width: 150,
          lineBreak: false,
        });
      doc
        .font('Helvetica')
        .fontSize(8)
        .fillColor('#4b5563')
        .text(`Paid Days : ${paidDays}`, cardX + 10, cardY + 40, {
          width: 150,
          lineBreak: false,
        });
      doc.text(`LOP Days : ${lopDays}`, cardX + 10, cardY + 50, {
        width: 150,
        lineBreak: false,
      });

      y = Math.max(y, cardY + 70);

      const colW = pageW / 4;
      const rowH = 15;
      doc.rect(left, y, pageW, 18).fill('#f6f7f9');
      doc.font('Helvetica-Bold').fontSize(7.5).fillColor('#8b919a');
      doc.text('EARNINGS', left + 5, y + 5, { width: colW - 8, lineBreak: false });
      doc.text('AMOUNT', left + colW + 5, y + 5, {
        width: colW - 8,
        align: 'right',
        lineBreak: false,
      });
      doc.text('DEDUCTIONS', left + colW * 2 + 5, y + 5, {
        width: colW - 8,
        lineBreak: false,
      });
      doc.text('AMOUNT', left + colW * 3 + 5, y + 5, {
        width: colW - 8,
        align: 'right',
        lineBreak: false,
      });
      y += 18;

      const rows = Math.max(earnings.length, deductions.length, 1);
      for (let i = 0; i < rows; i++) {
        if (y + rowH > contentBottom - 120) break;
        const e = earnings[i];
        const d = deductions[i];
        doc.font('Helvetica').fontSize(8).fillColor('#1a1d23');
        doc.text(e?.label ?? '', left + 5, y + 3, {
          width: colW - 8,
          lineBreak: false,
          ellipsis: true,
        });
        doc.text(e ? inr(e.amount) : '', left + colW + 5, y + 3, {
          width: colW - 8,
          align: 'right',
          lineBreak: false,
        });
        doc.text(d?.label ?? '', left + colW * 2 + 5, y + 3, {
          width: colW - 8,
          lineBreak: false,
          ellipsis: true,
        });
        doc.text(d ? inr(d.amount) : '', left + colW * 3 + 5, y + 3, {
          width: colW - 8,
          align: 'right',
          lineBreak: false,
        });
        y += rowH;
      }

      doc.rect(left, y, pageW, 17).fill('#f6f7f9');
      doc.font('Helvetica-Bold').fontSize(8).fillColor('#1a1d23');
      doc.text('Gross Earnings', left + 5, y + 4, {
        width: colW - 8,
        lineBreak: false,
      });
      doc.text(inr(gross), left + colW + 5, y + 4, {
        width: colW - 8,
        align: 'right',
        lineBreak: false,
      });
      doc.text('Total Deductions', left + colW * 2 + 5, y + 4, {
        width: colW - 8,
        lineBreak: false,
      });
      doc.text(inr(totalDed), left + colW * 3 + 5, y + 4, {
        width: colW - 8,
        align: 'right',
        lineBreak: false,
      });
      y += 22;

      doc.roundedRect(left, y, pageW, 34, 5).strokeColor('#e6e8ee').stroke();
      doc
        .font('Helvetica-Bold')
        .fontSize(9)
        .fillColor('#1a1d23')
        .text('TOTAL NET PAYABLE', left + 10, y + 6, { lineBreak: false });
      doc
        .font('Helvetica')
        .fontSize(7)
        .fillColor('#8b919a')
        .text('Gross Earnings - Total Deductions', left + 10, y + 18, {
          lineBreak: false,
        });
      doc.rect(left + pageW - 110, y, 110, 34).fill('#f3fbf6');
      doc
        .font('Helvetica-Bold')
        .fontSize(10)
        .fillColor('#1a1d23')
        .text(inr(net), left + pageW - 102, y + 12, {
          width: 94,
          align: 'right',
          lineBreak: false,
        });
      y += 42;

      doc
        .font('Helvetica')
        .fontSize(8)
        .fillColor('#4b5563')
        .text(`Amount In Words : ${inrWords(net)}`, left, y, {
          width: pageW,
          align: 'center',
          lineBreak: false,
          ellipsis: true,
        });
      y += 14;
      if (notes.trim() && y < contentBottom - 24) {
        doc
          .font('Helvetica')
          .fontSize(7.5)
          .fillColor('#6b7280')
          .text(notes.trim(), left, y, {
            width: pageW,
            align: 'center',
            height: 20,
            ellipsis: true,
          });
        y += 14;
      }
      doc
        .font('Helvetica')
        .fontSize(7.5)
        .fillColor('#b0b6c0')
        .text('-- This is a system-generated document. --', left, y, {
          width: pageW,
          align: 'center',
          lineBreak: false,
        });

      // ── Footer on page 1 only (logo + powered-by) ─────────────────────
      const range = doc.bufferedPageRange();
      doc.switchToPage(range.start);
      const footerY = doc.page.height - footerBand + 6;
      const markSize = 18;
      const powered = 'Powered by Arka Payroll';
      doc.font('Helvetica-Bold').fontSize(8);
      const textW = doc.widthOfString(powered);
      const blockW = (logoBuf ? markSize + 6 : 0) + textW;
      const blockX = left + (pageW - blockW) / 2;
      drawLogo(blockX, footerY, markSize);
      doc
        .fillColor('#14808f')
        .text(powered, blockX + (logoBuf ? markSize + 6 : 0), footerY + 4, {
          lineBreak: false,
        });

      doc.end();
    });
  }

  private defaultLines(slip: SlipRow): {
    earnings: SlipLine[];
    deductions: SlipLine[];
  } {
    const earn: SlipLine[] = [
      { label: 'Basic', amount: toNumber(slip.basicEarned) },
      { label: 'House Rent Allowance', amount: toNumber(slip.hraEarned) },
      { label: 'Travel allowance', amount: toNumber(slip.conveyanceEarned) },
    ];
    const special = toNumber(slip.specialAllowanceEarned);
    const medical = toNumber(slip.medicalEarned);
    const bonus = toNumber(slip.bonus);
    const other =
      toNumber(slip.otherEarnings) + toNumber(slip.specialAdjustment);
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
}

function loadPayslipLogo(): Buffer | null {
  const candidates = [
    join(process.cwd(), 'assets/payslip-logo.png'),
    join(process.cwd(), 'backend/assets/payslip-logo.png'),
    join(__dirname, '../../../assets/payslip-logo.png'),
    join(__dirname, '../../assets/payslip-logo.png'),
  ];
  for (const p of candidates) {
    if (!existsSync(p)) continue;
    try {
      return readFileSync(p);
    } catch {
      /* try next */
    }
  }
  return null;
}

function inr(n: number): string {
  return `Rs. ${new Intl.NumberFormat('en-IN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(n)}`;
}

function formatPayDate(value: string | Date | null | undefined): string {
  if (!value) return '-';
  if (typeof value === 'string') {
    const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(value.trim());
    if (m) return `${m[3]}/${m[2]}/${m[1]}`;
  }
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  const d = String(date.getUTCDate()).padStart(2, '0');
  const mo = String(date.getUTCMonth() + 1).padStart(2, '0');
  return `${d}/${mo}/${date.getUTCFullYear()}`;
}

function asSlipDocument(value: unknown): SlipDocument | undefined {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return undefined;
  }
  return value as SlipDocument;
}

function inrWords(amount: number): string {
  const n = Math.round(Math.abs(amount));
  if (n === 0) return 'Indian Rupee Zero Only';
  const ones = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];
  const tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];
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
  return `Indian Rupee ${parts.join(' ')} Only`;
}
