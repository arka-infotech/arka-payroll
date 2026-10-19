import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import type SMTPTransport from 'nodemailer/lib/smtp-transport';

export type PayslipMailPayload = {
  to: string;
  employeeName: string;
  /** e.g. "1 Sep 26 - 30 Sep 26" — used in the subject line */
  periodRange: string;
  /** e.g. "SEPTEMBER 2026" — used in the body */
  monthYearUpper: string;
  trackingReference: string;
  pdf: Buffer;
  filename: string;
};

const CONFIDENTIALITY_NOTE =
  'CONFIDENTIALITY NOTE: This message may contain confidential or legally privileged information. If you are not the intended recipient, you are hereby notified that any disclosure, copying, distribution, or taking any action in reliance on these contents is strictly prohibited and may be unlawful. If you have received this communication in error, please notify us immediately by responding to this e-mail and then delete it from your system.';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter | null = null;

  constructor(private readonly config: ConfigService) {}

  /** True when SMTP host + user + password are set. */
  isConfigured(): boolean {
    return !!(
      this.config.get<string>('SMTP_HOST')?.trim() &&
      this.config.get<string>('SMTP_USER')?.trim() &&
      this.config.get<string>('SMTP_PASS')?.trim()
    );
  }

  private getFrom(): string {
    const from =
      this.config.get<string>('MAIL_FROM')?.trim() ||
      this.config.get<string>('SMTP_USER')?.trim() ||
      'support@arkasoftware.in';
    const name =
      this.config.get<string>('MAIL_FROM_NAME')?.trim() ||
      'Arka Payroll';
    return `"${name}" <${from}>`;
  }

  private getTransporter(): nodemailer.Transporter | null {
    if (!this.isConfigured()) return null;
    if (this.transporter) return this.transporter;

    const port = Number(this.config.get<string>('SMTP_PORT') ?? 587);
    const secure =
      (this.config.get<string>('SMTP_SECURE') ?? '').toLowerCase() === 'true' ||
      port === 465;

    const options: SMTPTransport.Options = {
      host: this.config.get<string>('SMTP_HOST')!.trim(),
      port,
      secure,
      auth: {
        user: this.config.get<string>('SMTP_USER')!.trim(),
        pass: this.config.get<string>('SMTP_PASS')!.trim(),
      },
    };

    this.transporter = nodemailer.createTransport(options);
    return this.transporter;
  }

  /**
   * Emails the locked payslip PDF to the employee.
   * No-ops (with a log) when SMTP env is incomplete so punch still succeeds.
   */
  async sendPayslipPdf(payload: PayslipMailPayload): Promise<boolean> {
    const transport = this.getTransporter();
    if (!transport) {
      this.logger.warn(
        `SMTP not configured — skipped payslip email to ${payload.to}`,
      );
      return false;
    }

    const company =
      this.config.get<string>('COMPANY_NAME')?.trim() ||
      'Arka Infotech Software Solutions';

    const subject = `${company} - Pay Slip: ${payload.periodRange}`;
    const text = [
      'Dear Employee,',
      '',
      `Please find attached your Pay Slip for the month of ${payload.monthYearUpper}.`,
      '',
      'DO NOT REPLY TO THIS EMAIL ADDRESS',
      '',
      CONFIDENTIALITY_NOTE,
    ].join('\n');
    const html = `
      <p>Dear Employee,</p>
      <p>Please find attached your Pay Slip for the month of <strong>${escapeHtml(payload.monthYearUpper)}</strong>.</p>
      <p><strong>DO NOT REPLY TO THIS EMAIL ADDRESS</strong></p>
      <p style="font-size:12px;color:#555;">${escapeHtml(CONFIDENTIALITY_NOTE)}</p>
    `;

    await transport.sendMail({
      from: this.getFrom(),
      to: payload.to,
      subject,
      text,
      html,
      attachments: [
        {
          filename: payload.filename,
          content: payload.pdf,
          contentType: 'application/pdf',
        },
      ],
    });

    this.logger.log(
      `Payslip emailed to ${payload.to} (${payload.trackingReference})`,
    );
    return true;
  }
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
