import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import type SMTPTransport from 'nodemailer/lib/smtp-transport';

export type PayslipMailPayload = {
  to: string;
  employeeName: string;
  periodLabel: string;
  trackingReference: string;
  pdf: Buffer;
  filename: string;
};

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

    await transport.sendMail({
      from: this.getFrom(),
      to: payload.to,
      subject: `Payslip · ${payload.periodLabel} · ${payload.trackingReference}`,
      text: [
        `Hi ${payload.employeeName},`,
        '',
        `Your payslip for ${payload.periodLabel} is attached.`,
        `Reference: ${payload.trackingReference}`,
        '',
        `— ${company}`,
      ].join('\n'),
      html: `
        <p>Hi ${escapeHtml(payload.employeeName)},</p>
        <p>Your payslip for <strong>${escapeHtml(payload.periodLabel)}</strong> is attached.</p>
        <p>Reference: <code>${escapeHtml(payload.trackingReference)}</code></p>
        <p>— ${escapeHtml(company)}</p>
      `,
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
