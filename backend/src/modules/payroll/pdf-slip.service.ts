import { existsSync, readFileSync } from 'fs';
import { join } from 'path';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import PDFDocument from 'pdfkit';
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
    const period = `${MONTH_NAMES[slip.month]} ${slip.year}`;
    const u = slip.user;
    const employeeName =
      docJson?.employeeName?.trim() || `${u.firstName} ${u.lastName}`;
    const employeeCode =
      docJson?.employeeCode?.trim() || u.employeeCode || '-';
    const paidDays = docJson?.paidDays ?? slip.daysPayable;
    const lopDays = docJson?.lopDays ?? slip.unpaidLeaveDays;
    const payDate = formatPayDate(docJson?.payDate ?? slip.payDate);
    const notes = docJson?.notes ?? slip.slipNotes ?? '';

    const logoPath = [
      join(process.cwd(), 'assets/payslip-logo.png'),
      join(process.cwd(), 'backend/assets/payslip-logo.png'),
    ].find((p) => existsSync(p));

    return new Promise<Buffer>((resolve, reject) => {
      const doc = new PDFDocument({
        size: 'A4',
        margins: { top: 40, bottom: 48, left: 42, right: 42 },
      });
      const chunks: Buffer[] = [];
      doc.on('data', (c: Buffer) => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const pageW =
        doc.page.width - doc.page.margins.left - doc.page.margins.right;
      let y = doc.page.margins.top;

      if (logoPath) {
        try {
          doc.image(readFileSync(logoPath), doc.page.margins.left, y, {
            fit: [48, 48],
          });
        } catch {
          /* ignore logo errors */
        }
      }
      doc
        .font('Helvetica-Bold')
        .fontSize(14)
        .fillColor('#1a1d23')
        .text(company, doc.page.margins.left + 56, y, { width: pageW - 200 });
      doc
        .font('Helvetica')
        .fontSize(8)
        .fillColor('#8b919a')
        .text(location, doc.page.margins.left + 56, y + 18, {
          width: pageW - 200,
        });
      doc
        .font('Helvetica')
        .fontSize(9)
        .fillColor('#8b919a')
        .text('Payslip For the Month', doc.page.margins.left, y, {
          width: pageW,
          align: 'right',
        });
      doc
        .font('Helvetica-Bold')
        .fontSize(12)
        .fillColor('#1a1d23')
        .text(period, doc.page.margins.left, y + 14, {
          width: pageW,
          align: 'right',
        });

      y += 64;
      doc
        .font('Helvetica-Bold')
        .fontSize(9)
        .fillColor('#8b919a')
        .text('EMPLOYEE SUMMARY', doc.page.margins.left, y);
      y += 16;

      const kv = (label: string, value: string) => {
        doc
          .font('Helvetica')
          .fontSize(9)
          .fillColor('#6b7280')
          .text(label, doc.page.margins.left, y, { width: 90 });
        doc
          .fillColor('#9aa1ab')
          .text(':', doc.page.margins.left + 90, y, { width: 12 });
        doc
          .font('Helvetica-Bold')
          .fillColor('#1a1d23')
          .text(value, doc.page.margins.left + 104, y, { width: 200 });
        y += 14;
      };
      kv('Employee Name', employeeName);
      kv('Employee ID', employeeCode);
      kv('Pay Period', period);
      kv('Pay Date', payDate);

      const cardX = doc.page.margins.left + pageW - 190;
      const cardY = y - 70;
      doc
        .roundedRect(cardX, cardY, 190, 70, 6)
        .strokeColor('#e6e8ee')
        .stroke();
      doc.rect(cardX, cardY, 190, 40).fill('#f3fbf6');
      doc
        .font('Helvetica-Bold')
        .fontSize(13)
        .fillColor('#1a1d23')
        .text(inr(net), cardX + 12, cardY + 10, { width: 166 });
      doc
        .font('Helvetica')
        .fontSize(8)
        .fillColor('#6b7280')
        .text('Total Net Pay', cardX + 12, cardY + 26, { width: 166 });
      doc
        .font('Helvetica')
        .fontSize(9)
        .fillColor('#4b5563')
        .text(`Paid Days : ${paidDays}`, cardX + 12, cardY + 46, {
          width: 166,
        });
      doc.text(`LOP Days : ${lopDays}`, cardX + 12, cardY + 58, {
        width: 166,
      });

      y = Math.max(y, cardY + 82);

      const colW = pageW / 4;
      const drawHeader = () => {
        doc.rect(doc.page.margins.left, y, pageW, 22).fill('#f6f7f9');
        doc.font('Helvetica-Bold').fontSize(8).fillColor('#8b919a');
        doc.text('EARNINGS', doc.page.margins.left + 6, y + 7, {
          width: colW - 8,
        });
        doc.text('AMOUNT', doc.page.margins.left + colW + 6, y + 7, {
          width: colW - 8,
          align: 'right',
        });
        doc.text('DEDUCTIONS', doc.page.margins.left + colW * 2 + 6, y + 7, {
          width: colW - 8,
        });
        doc.text('AMOUNT', doc.page.margins.left + colW * 3 + 6, y + 7, {
          width: colW - 8,
          align: 'right',
        });
        y += 22;
      };
      drawHeader();
      doc.strokeColor('#e6e8ee');

      const rows = Math.max(earnings.length, deductions.length, 1);
      for (let i = 0; i < rows; i++) {
        const e = earnings[i];
        const d = deductions[i];
        doc.font('Helvetica').fontSize(9).fillColor('#1a1d23');
        doc.text(e?.label ?? '', doc.page.margins.left + 6, y + 5, {
          width: colW - 8,
        });
        doc.text(e ? inr(e.amount) : '', doc.page.margins.left + colW + 6, y + 5, {
          width: colW - 8,
          align: 'right',
        });
        doc.text(d?.label ?? '', doc.page.margins.left + colW * 2 + 6, y + 5, {
          width: colW - 8,
        });
        doc.text(
          d ? inr(d.amount) : '',
          doc.page.margins.left + colW * 3 + 6,
          y + 5,
          { width: colW - 8, align: 'right' },
        );
        y += 18;
      }

      doc.rect(doc.page.margins.left, y, pageW, 20).fill('#f6f7f9');
      doc.font('Helvetica-Bold').fontSize(9).fillColor('#1a1d23');
      doc.text('Gross Earnings', doc.page.margins.left + 6, y + 5, {
        width: colW - 8,
      });
      doc.text(inr(gross), doc.page.margins.left + colW + 6, y + 5, {
        width: colW - 8,
        align: 'right',
      });
      doc.text('Total Deductions', doc.page.margins.left + colW * 2 + 6, y + 5, {
        width: colW - 8,
      });
      doc.text(inr(totalDed), doc.page.margins.left + colW * 3 + 6, y + 5, {
        width: colW - 8,
        align: 'right',
      });
      y += 28;

      doc
        .roundedRect(doc.page.margins.left, y, pageW, 40, 6)
        .strokeColor('#e6e8ee')
        .stroke();
      doc
        .font('Helvetica-Bold')
        .fontSize(10)
        .fillColor('#1a1d23')
        .text('TOTAL NET PAYABLE', doc.page.margins.left + 12, y + 8);
      doc
        .font('Helvetica')
        .fontSize(8)
        .fillColor('#8b919a')
        .text('Gross Earnings - Total Deductions', doc.page.margins.left + 12, y + 22);
      doc
        .rect(doc.page.margins.left + pageW - 120, y, 120, 40)
        .fill('#f3fbf6');
      doc
        .font('Helvetica-Bold')
        .fontSize(11)
        .fillColor('#1a1d23')
        .text(inr(net), doc.page.margins.left + pageW - 112, y + 14, {
          width: 104,
          align: 'right',
        });
      y += 52;

      doc
        .font('Helvetica')
        .fontSize(9)
        .fillColor('#4b5563')
        .text(`Amount In Words : ${inrWords(net)}`, doc.page.margins.left, y, {
          width: pageW,
          align: 'center',
        });
      y += 18;
      if (notes.trim()) {
        doc
          .font('Helvetica')
          .fontSize(8)
          .fillColor('#6b7280')
          .text(notes.trim(), doc.page.margins.left, y, {
            width: pageW,
            align: 'center',
          });
        y += 16;
      }
      doc
        .font('Helvetica')
        .fontSize(8)
        .fillColor('#b0b6c0')
        .text('-- This is a system-generated document. --', doc.page.margins.left, y, {
          width: pageW,
          align: 'center',
        });
      doc
        .font('Helvetica-Bold')
        .fontSize(8)
        .fillColor('#14808f')
        .text(
          'Powered by Arka Payroll',
          doc.page.margins.left,
          doc.page.height - 36,
          { width: pageW, align: 'center' },
        );

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

function inr(n: number): string {
  return `Rs. ${new Intl.NumberFormat('en-IN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(n)}`;
}

function formatPayDate(value: string | Date | null | undefined): string {
  if (!value) return '-';
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toLocaleDateString('en-GB');
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
