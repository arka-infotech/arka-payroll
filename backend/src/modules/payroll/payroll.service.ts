import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PayrollStatus, Prisma, Role } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { AppRole } from '../../common/enums/role.enum';
import { ProcessPayrollDto } from './dto/process-payroll.dto';
import {
  buildTrackingReference,
  computeMonthlyPayroll,
  daysInMonth,
  SalaryStructureInput,
} from './domain/payroll-calculator';
import { toNumber } from './domain/money.util';
import { PdfSlipService } from './pdf-slip.service';
import { AuditService } from '../audit/audit.service';
import { MailService } from '../mail/mail.service';
import { JwtPayload } from '../auth/interfaces/jwt-payload.interface';
import {
  canManageUser,
  visibleUsersWhere,
} from '../users/user-visibility.util';

const MONTH_LABELS = [
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

const MONTH_SHORT = [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/** e.g. year=2026, month=9 → "1 Sep 26 - 30 Sep 26" */
function formatPayslipPeriodRange(year: number, month: number): string {
  const lastDay = new Date(year, month, 0).getDate();
  const short = MONTH_SHORT[month] ?? String(month);
  const yy = String(year).slice(-2);
  return `1 ${short} ${yy} - ${lastDay} ${short} ${yy}`;
}

@Injectable()
export class PayrollService {
  private readonly logger = new Logger(PayrollService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly pdfSlip: PdfSlipService,
    private readonly audit: AuditService,
    private readonly config: ConfigService,
    private readonly mail: MailService,
  ) {}

  async dashboardStats() {
    const [activeEmployees, pendingDrafts, lockedThisMonth] = await Promise.all([
      this.prisma.user.count({
        where: {
          role: { not: Role.SUPER_ADMIN },
          status: 'ACTIVE',
        },
      }),
      this.prisma.monthlyPayroll.count({
        where: { status: PayrollStatus.DRAFT },
      }),
      this.prisma.monthlyPayroll.count({
        where: {
          status: { in: [PayrollStatus.LOCKED, PayrollStatus.PROCESSED] },
          year: new Date().getFullYear(),
          month: new Date().getMonth() + 1,
        },
      }),
    ]);
    return {
      activeEmployees,
      pendingSlips: pendingDrafts,
      processedThisMonth: lockedThisMonth,
      calendarDaysInMonth: daysInMonth(
        new Date().getFullYear(),
        new Date().getMonth() + 1,
      ),
    };
  }

  /** Dry-run calculation for HR preview modal — no DB write. */
  async preview(dto: ProcessPayrollDto, actor: JwtPayload) {
    const maxDays = daysInMonth(dto.year, dto.month);
    if (dto.workingDaysInMonth > maxDays) {
      throw new BadRequestException(
        `Days worked (${dto.workingDaysInMonth}) exceeds ${dto.year}-${dto.month} capacity (${maxDays})`,
      );
    }
    if (dto.unpaidLeaveDays > dto.workingDaysInMonth) {
      throw new BadRequestException(
        'Unpaid leave days cannot exceed days worked',
      );
    }

    const user = await this.loadEmployeeWithStructure(dto.userId);
    if (!canManageUser(actor, user)) {
      throw new ForbiddenException('Cannot preview payroll for this user');
    }
    const structure = this.structureForCompute(user.salaryStructure!);

    const computed = computeMonthlyPayroll(structure, {
      year: dto.year,
      month: dto.month,
      workingDaysInMonth: dto.workingDaysInMonth,
      unpaidLeaveDays: dto.unpaidLeaveDays,
      bonus: dto.bonus ?? 0,
      specialAdjustment: dto.specialAdjustment ?? 0,
      otherEarnings: dto.otherEarnings ?? 0,
      otherDeductions: dto.otherDeductions ?? 0,
      epfOnActuals: dto.epfOnActuals,
    });

    return {
      employee: {
        id: user.id,
        name: `${user.firstName} ${user.lastName}`,
        designation: user.designation,
        employeeCode: user.employeeCode,
        pan: user.pan ?? 'N/A',
        uan: user.uan ?? 'N/A',
        bankName: user.bankName ?? 'N/A',
        bankAccountNumber: user.bankAccountNumber ?? 'N/A',
        bankIfsc: user.bankIfsc ?? 'N/A',
      },
      calendarDaysInMonth: maxDays,
      ...computed,
    };
  }

  /**
   * Process + auto-LOCK for tax reporting integrity.
   * Re-locking an already locked month simply updates the slip.
   */
  async processMonthly(dto: ProcessPayrollDto, actor: JwtPayload) {
    const maxDays = daysInMonth(dto.year, dto.month);
    if (dto.workingDaysInMonth > maxDays) {
      throw new BadRequestException(
        `Days worked (${dto.workingDaysInMonth}) exceeds calendar capacity (${maxDays})`,
      );
    }

    const user = await this.loadEmployeeWithStructure(dto.userId);

    const existing = await this.prisma.monthlyPayroll.findUnique({
      where: {
        userId_year_month: {
          userId: dto.userId,
          year: dto.year,
          month: dto.month,
        },
      },
    });

    if (!canManageUser(actor, user)) {
      throw new ForbiddenException('Cannot process payroll for this user');
    }

    const structure = this.structureForCompute(user.salaryStructure!);

    const computed = computeMonthlyPayroll(structure, {
      year: dto.year,
      month: dto.month,
      workingDaysInMonth: dto.workingDaysInMonth,
      unpaidLeaveDays: dto.unpaidLeaveDays,
      bonus: dto.bonus ?? 0,
      specialAdjustment: dto.specialAdjustment ?? 0,
      otherEarnings: dto.otherEarnings ?? 0,
      otherDeductions: dto.otherDeductions ?? 0,
      epfOnActuals: dto.epfOnActuals,
    });

    const trackingReference =
      existing?.trackingReference ??
      buildTrackingReference(dto.year, dto.month, user.employeeCode, user.id);

    const row = await this.prisma.$transaction(async (tx) => {
      const data = {
        workingDaysInMonth: dto.workingDaysInMonth,
        daysPayable: computed.daysPayable,
        unpaidLeaveDays: dto.unpaidLeaveDays,
        bonus: computed.bonus,
        specialAdjustment: computed.specialAdjustment,
        otherEarnings: computed.otherEarnings,
        basicEarned: computed.basicEarned,
        hraEarned: computed.hraEarned,
        specialAllowanceEarned: computed.specialAllowanceEarned,
        conveyanceEarned: computed.conveyanceEarned,
        medicalEarned: computed.medicalEarned,
        grossEarnings: computed.grossEarnings,
        epfEmployee: computed.epfEmployee,
        esicEmployee: computed.esicEmployee,
        professionalTax: computed.professionalTax,
        tds: computed.tds,
        otherDeductions: computed.otherDeductions,
        totalDeductions: computed.totalDeductions,
        netPay: computed.netPay,
        trackingReference,
        status: PayrollStatus.LOCKED,
        processedAt: new Date(),
        processedBy: actor.sub,
        calculationSnapshot: computed.snapshot as Prisma.InputJsonValue,
        slipNotes: dto.slipNotes?.trim() || null,
        payDate: creditDate(dto.year, dto.month, user.salaryStructure?.salaryCreditDay),
        slipDocument: this.brandingDocument(existing?.slipDocument),
      };

      if (existing) {
        return tx.monthlyPayroll.update({
          where: { id: existing.id },
          data,
        });
      }

      return tx.monthlyPayroll.create({
        data: {
          id: randomUUID(),
          userId: dto.userId,
          year: dto.year,
          month: dto.month,
          ...data,
        },
      });
    });

    await this.audit.write({
      actorId: actor.sub,
      actorEmail: actor.email,
      actorRole: actor.role,
      action: 'PAYROLL_LOCK',
      entity: 'monthly_payroll',
      entityId: row.id,
      summary: `Locked payroll ${trackingReference} net ₹${computed.netPay}`,
    });

    await this.prisma.monthlyPayroll.update({
      where: { id: row.id },
      data: { emailStatus: 'PENDING', emailError: null, emailSentAt: null },
    });

    void this.emailLockedSlip(row.id, actor).catch((err) => {
      const detail = err instanceof Error ? err.message : String(err);
      this.logger.warn(`Payslip email failed for ${row.id}: ${detail}`);
    });

    return this.prisma.monthlyPayroll.findUniqueOrThrow({
      where: { id: row.id },
      include: {
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            employeeCode: true,
            email: true,
          },
        },
      },
    });
  }

  /** Best-effort email after lock — never blocks payroll confirmation. */
  private async emailLockedSlip(
    payrollId: string,
    actor: JwtPayload,
  ): Promise<void> {
    if (!this.mail.isConfigured()) {
      await this.prisma.monthlyPayroll.update({
        where: { id: payrollId },
        data: {
          emailStatus: 'SKIPPED',
          emailError: 'SMTP not configured',
          emailSentAt: null,
        },
      });
      return;
    }

    const slip = await this.getSlipMeta(payrollId, actor);
    const to = slip.user.email?.trim();
    if (!to) {
      this.logger.warn(`No employee email for payroll ${payrollId}`);
      await this.prisma.monthlyPayroll.update({
        where: { id: payrollId },
        data: {
          emailStatus: 'SKIPPED',
          emailError: 'Employee has no email',
          emailSentAt: null,
        },
      });
      return;
    }

    try {
      const { buffer, filename } = await this.generatePdfBuffer(payrollId, actor);
      await this.mail.sendPayslipPdf({
        to,
        employeeName: `${slip.user.firstName} ${slip.user.lastName}`.trim(),
        periodRange: formatPayslipPeriodRange(slip.year, slip.month),
        monthYearUpper: `${MONTH_LABELS[slip.month].toUpperCase()} ${slip.year}`,
        trackingReference: slip.trackingReference,
        pdf: buffer,
        filename,
      });
      await this.prisma.monthlyPayroll.update({
        where: { id: payrollId },
        data: {
          emailStatus: 'SENT',
          emailSentAt: new Date(),
          emailError: null,
        },
      });
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      await this.prisma.monthlyPayroll.update({
        where: { id: payrollId },
        data: {
          emailStatus: 'FAILED',
          emailError: detail.slice(0, 500),
          emailSentAt: null,
        },
      });
      throw err;
    }
  }

  async processBatch(
    year: number,
    month: number,
    entries: ProcessPayrollDto[],
    actor: JwtPayload,
  ) {
    const results = [];
    for (const entry of entries) {
      results.push(await this.processMonthly({ ...entry, year, month }, actor));
    }
    return results;
  }

  async listForPeriod(year: number, month: number, requester: JwtPayload) {
    await this.ensureAutoDraftsForPeriod(year, month, requester);

    return this.prisma.monthlyPayroll.findMany({
      where: {
        year,
        month,
        user: visibleUsersWhere(requester),
      },
      include: {
        user: {
          select: {
            id: true,
            role: true,
            firstName: true,
            lastName: true,
            employeeCode: true,
            designation: true,
            email: true,
          },
        },
      },
      orderBy: { trackingReference: 'asc' },
    });
  }

  async getSlipMeta(
    payrollId: string,
    requester: { sub: string; role: AppRole },
  ) {
    const row = await this.prisma.monthlyPayroll.findUnique({
      where: { id: payrollId },
      include: {
        user: {
          select: {
            id: true,
            role: true,
            firstName: true,
            lastName: true,
            employeeCode: true,
            designation: true,
            dateOfJoining: true,
            pan: true,
            uan: true,
            bankName: true,
            bankAccountNumber: true,
            bankIfsc: true,
            email: true,
          },
        },
      },
    });

    if (!row || row.user.role === Role.SUPER_ADMIN) {
      throw new NotFoundException('Salary slip not found');
    }

    if (
      requester.role === AppRole.EMPLOYEE &&
      row.userId !== requester.sub
    ) {
      throw new ForbiddenException('You may only view your own salary slips');
    }

    if (
      requester.role === AppRole.HR_ADMIN &&
      !canManageUser(requester, row.user)
    ) {
      throw new ForbiddenException('You may not view this salary slip');
    }

    return row;
  }

  async listMySlips(userId: string) {
    return this.prisma.monthlyPayroll.findMany({
      where: {
        userId,
        status: {
          in: [
            PayrollStatus.DRAFT,
            PayrollStatus.PROCESSED,
            PayrollStatus.LOCKED,
            PayrollStatus.PAID,
          ],
        },
      },
      orderBy: [{ year: 'desc' }, { month: 'desc' }],
    });
  }

  /** Save punch variables without locking — edits auto-generated DRAFT slips. */
  async saveDraft(dto: ProcessPayrollDto, actor: JwtPayload) {
    const maxDays = daysInMonth(dto.year, dto.month);
    if (dto.workingDaysInMonth > maxDays) {
      throw new BadRequestException(
        `Days worked (${dto.workingDaysInMonth}) exceeds calendar capacity (${maxDays})`,
      );
    }

    const user = await this.loadEmployeeWithStructure(dto.userId);
    if (!canManageUser(actor, user)) {
      throw new ForbiddenException('Cannot edit payroll for this user');
    }

    const existing = await this.prisma.monthlyPayroll.findUnique({
      where: {
        userId_year_month: {
          userId: dto.userId,
          year: dto.year,
          month: dto.month,
        },
      },
    });

    await this.writeDraftRow(user, dto, existing, true);
    return this.prisma.monthlyPayroll.findUnique({
      where: {
        userId_year_month: {
          userId: dto.userId,
          year: dto.year,
          month: dto.month,
        },
      },
    });
  }

  /** Creates or refreshes a DRAFT slip from pay package (on save structure or credit day). */
  async materializeDraftForUser(userId: string, year: number, month: number) {
    let user;
    try {
      user = await this.loadEmployeeWithStructure(userId);
    } catch {
      return null;
    }

    const existing = await this.prisma.monthlyPayroll.findUnique({
      where: {
        userId_year_month: { userId, year, month },
      },
    });

    if (
      existing &&
      (existing.status === PayrollStatus.LOCKED ||
        existing.status === PayrollStatus.PAID)
    ) {
      return existing;
    }

    const calDays = daysInMonth(year, month);
    const prev = await this.prisma.monthlyPayroll.findFirst({
      where: {
        userId,
        OR: [{ year: { lt: year } }, { year, month: { lt: month } }],
      },
      orderBy: [{ year: 'desc' }, { month: 'desc' }],
    });

    const dto: ProcessPayrollDto = {
      userId,
      year,
      month,
      workingDaysInMonth:
        existing?.workingDaysInMonth ?? prev?.workingDaysInMonth ?? calDays,
      unpaidLeaveDays:
        existing?.unpaidLeaveDays ?? prev?.unpaidLeaveDays ?? 0,
      bonus: existing ? toNumber(existing.bonus) : toNumber(prev?.bonus ?? 0),
      specialAdjustment: existing
        ? toNumber(existing.specialAdjustment)
        : toNumber(prev?.specialAdjustment ?? 0),
      otherEarnings: existing
        ? toNumber(existing.otherEarnings)
        : toNumber(prev?.otherEarnings ?? 0),
      slipNotes: existing?.slipNotes ?? prev?.slipNotes ?? undefined,
    };

    return this.writeDraftRow(user, dto, existing);
  }

  async ensureAutoDraftsForPeriod(
    year: number,
    month: number,
    requester: JwtPayload,
  ) {
    const now = new Date();
    const isCurrent =
      year === now.getFullYear() && month === now.getMonth() + 1;
    if (!isCurrent) return;

    const users = await this.prisma.user.findMany({
      where: {
        ...visibleUsersWhere(requester),
        status: 'ACTIVE',
        salaryStructure: { isNot: null },
      },
      include: { salaryStructure: true },
    });

    for (const u of users) {
      const creditDay = u.salaryStructure?.salaryCreditDay ?? 1;
      if (now.getDate() < creditDay) continue;
      await this.materializeDraftForUser(u.id, year, month);
    }
  }

  private async writeDraftRow(
    user: {
      id: string;
      employeeCode: string | null;
      salaryStructure: NonNullable<
        Awaited<ReturnType<PayrollService['loadEmployeeWithStructure']>>
      >['salaryStructure'];
    },
    dto: ProcessPayrollDto,
    existing: {
      id: string;
      trackingReference: string;
      slipDocument?: Prisma.JsonValue | null;
    } | null,
    resetDocument = false,
  ) {
    const structure = this.structureForCompute(user.salaryStructure!);

    const computed = computeMonthlyPayroll(structure, {
      year: dto.year,
      month: dto.month,
      workingDaysInMonth: dto.workingDaysInMonth,
      unpaidLeaveDays: dto.unpaidLeaveDays,
      bonus: dto.bonus ?? 0,
      specialAdjustment: dto.specialAdjustment ?? 0,
      otherEarnings: dto.otherEarnings ?? 0,
      otherDeductions: dto.otherDeductions ?? 0,
      epfOnActuals: dto.epfOnActuals,
    });

    const trackingReference =
      existing?.trackingReference ??
      buildTrackingReference(dto.year, dto.month, user.employeeCode, user.id);

    const data = {
      workingDaysInMonth: dto.workingDaysInMonth,
      daysPayable: computed.daysPayable,
      unpaidLeaveDays: dto.unpaidLeaveDays,
      bonus: computed.bonus,
      specialAdjustment: computed.specialAdjustment,
      otherEarnings: computed.otherEarnings,
      basicEarned: computed.basicEarned,
      hraEarned: computed.hraEarned,
      specialAllowanceEarned: computed.specialAllowanceEarned,
      conveyanceEarned: computed.conveyanceEarned,
      medicalEarned: computed.medicalEarned,
      grossEarnings: computed.grossEarnings,
      epfEmployee: computed.epfEmployee,
      esicEmployee: computed.esicEmployee,
      professionalTax: computed.professionalTax,
      tds: computed.tds,
      otherDeductions: computed.otherDeductions,
      totalDeductions: computed.totalDeductions,
      netPay: computed.netPay,
      trackingReference,
      status: PayrollStatus.DRAFT,
      processedAt: null,
      processedBy: null,
      calculationSnapshot: computed.snapshot as Prisma.InputJsonValue,
      slipNotes: dto.slipNotes?.trim() || null,
      ...(!existing?.slipDocument
        ? { slipDocument: this.brandingDocument(null) }
        : {}),
      ...(resetDocument
        ? {
            payDate: creditDate(
              dto.year,
              dto.month,
              user.salaryStructure?.salaryCreditDay,
            ),
            slipDocument: this.brandingDocument(existing?.slipDocument),
          }
        : {}),
    };

    if (existing) {
      return this.prisma.monthlyPayroll.update({
        where: { id: existing.id },
        data,
      });
    }

    return this.prisma.monthlyPayroll.create({
      data: {
        id: randomUUID(),
        userId: user.id,
        year: dto.year,
        month: dto.month,
        ...data,
        payDate: creditDate(
          dto.year,
          dto.month,
          user.salaryStructure?.salaryCreditDay,
        ),
        slipDocument: this.brandingDocument(null),
      },
    });
  }

  /** Company name and address stored on the slip so later edits keep this format. */
  private brandingDocument(existing: Prisma.JsonValue | null | undefined): Prisma.InputJsonValue {
    const prev =
      existing && typeof existing === 'object' && !Array.isArray(existing)
        ? (existing as Record<string, unknown>)
        : {};
    const savedName = typeof prev.companyName === 'string' ? prev.companyName.trim() : '';
    const savedLocation = typeof prev.location === 'string' ? prev.location.trim() : '';
    return {
      companyName:
        savedName ||
        this.config.get<string>('COMPANY_NAME', 'Arka Infotech Software Solutions'),
      location:
        savedLocation ||
        this.config.get<string>(
          'COMPANY_ADDRESS',
          'Office .no 512, Suchita Business Park, Patel chowk, opposite Hanuman temple, Shival Nagar, Saibaba Nagar, Pant Nagar, Ghatkopar East, Mumbai, Maharashtra 400077',
        ),
    };
  }

  async updateSlipDocument(
    payrollId: string,
    dto: import('./dto/update-slip-document.dto').UpdateSlipDocumentDto,
    actor: JwtPayload,
  ) {
    const slip = await this.getSlipMeta(payrollId, actor);
    if (!canManageUser(actor, slip.user)) {
      throw new ForbiddenException('Cannot edit this salary slip');
    }

    const earnings = dto.earnings.map((l) => ({
      label: l.label.trim(),
      amount: roundMoney(l.amount),
    }));
    const deductions = dto.deductions.map((l) => ({
      label: l.label.trim(),
      amount: roundMoney(l.amount),
    }));
    const gross = roundMoney(earnings.reduce((s, l) => s + l.amount, 0));
    const totalDeductions = roundMoney(
      deductions.reduce((s, l) => s + l.amount, 0),
    );
    const net = roundMoney(gross - totalDeductions);
    const document = {
      companyName:
        dto.companyName?.trim() ||
        this.config.get<string>('COMPANY_NAME', 'Arka Infotech Software Solutions'),
      location:
        dto.location?.trim() ||
        this.config.get<string>(
          'COMPANY_ADDRESS',
          'Office .no 512, Suchita Business Park, Patel chowk, opposite Hanuman temple, Shival Nagar, Saibaba Nagar, Pant Nagar, Ghatkopar East, Mumbai, Maharashtra 400077',
        ),
      employeeName: dto.employeeName?.trim() || undefined,
      employeeCode: dto.employeeCode?.trim() || undefined,
      payDate: dto.payDate?.trim() || undefined,
      paidDays: dto.paidDays,
      lopDays: dto.lopDays,
      notes: dto.notes?.trim() || undefined,
      earnings,
      deductions,
    };

    const updated = await this.prisma.monthlyPayroll.update({
      where: { id: payrollId },
      data: {
        daysPayable: dto.paidDays,
        unpaidLeaveDays: dto.lopDays,
        grossEarnings: gross,
        totalDeductions,
        netPay: net,
        slipNotes: dto.notes?.trim() || null,
        payDate:
          dto.payDate && !Number.isNaN(Date.parse(dto.payDate))
            ? new Date(dto.payDate)
            : slip.payDate,
        slipDocument: document as Prisma.InputJsonValue,
      },
    });

    // Editing a locked slip from Payslips should re-send the PDF (same as re-lock).
    if (
      slip.status === PayrollStatus.LOCKED ||
      slip.status === PayrollStatus.PROCESSED
    ) {
      await this.prisma.monthlyPayroll.update({
        where: { id: payrollId },
        data: { emailStatus: 'PENDING', emailError: null, emailSentAt: null },
      });
      void this.emailLockedSlip(payrollId, actor).catch((err) => {
        const detail = err instanceof Error ? err.message : String(err);
        this.logger.warn(`Payslip email failed for ${payrollId}: ${detail}`);
      });
    }

    return updated;
  }

  async generatePdfBuffer(
    payrollId: string,
    requester: { sub: string; role: AppRole },
  ): Promise<{ buffer: Buffer; filename: string }> {
    const slip = await this.getSlipMeta(payrollId, requester);
    const buffer = await this.pdfSlip.renderA4(slip);
    return { buffer, filename: `${slip.trackingReference}.pdf` };
  }

  async listPayrollGridSeed(
    year: number,
    month: number,
    requester: JwtPayload,
  ) {
    await this.ensureAutoDraftsForPeriod(year, month, requester);

    const employees = await this.prisma.user.findMany({
      where: {
        ...visibleUsersWhere(requester),
        status: 'ACTIVE',
      },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        employeeCode: true,
        designation: true,
        pan: true,
        uan: true,
        bankName: true,
        bankAccountNumber: true,
        bankIfsc: true,
        email: true,
        salaryStructure: true,
        monthlyPayrolls: {
          where: { year, month },
          take: 1,
        },
      },
      orderBy: { firstName: 'asc' },
    });

    const calendarDays = daysInMonth(year, month);

    return employees.map((e) => ({
      userId: e.id,
      name: `${e.firstName} ${e.lastName}`,
      employeeCode: e.employeeCode,
      designation: e.designation ?? 'N/A',
      pan: e.pan ?? 'N/A',
      uan: e.uan ?? 'N/A',
      bankName: e.bankName ?? 'N/A',
      bankAccountNumber: e.bankAccountNumber ?? 'N/A',
      bankIfsc: e.bankIfsc ?? 'N/A',
      email: e.email,
      hasStructure: !!e.salaryStructure,
      monthlyCtc: e.salaryStructure
        ? roundMonthlyCtc(e.salaryStructure)
        : null,
      calendarDaysInMonth: calendarDays,
      existingPayroll: e.monthlyPayrolls[0] ?? null,
    }));
  }

  private structureForCompute(
    salaryStructure: Exclude<
      NonNullable<
        Awaited<ReturnType<PayrollService['loadEmployeeWithStructure']>>
      >['salaryStructure'],
      null
    >,
  ): SalaryStructureInput {
    return {
      annualCtc: salaryStructure.annualCtc,
      basicMonthly: salaryStructure.basicMonthly,
      hraMonthly: salaryStructure.hraMonthly,
      specialAllowanceMonthly: salaryStructure.specialAllowanceMonthly,
      conveyanceMonthly: salaryStructure.conveyanceMonthly,
      medicalMonthly: salaryStructure.medicalMonthly,
      epfApplicable: salaryStructure.epfApplicable,
      esicApplicable: salaryStructure.esicApplicable,
      taxRegime: salaryStructure.taxRegime,
      professionalTaxApplicable: salaryStructure.professionalTaxApplicable,
      tdsApplicable: salaryStructure.tdsApplicable,
    };
  }

  private async loadEmployeeWithStructure(userId: string) {
    const user = await this.prisma.user.findFirst({
      where: {
        id: userId,
        role: { not: Role.SUPER_ADMIN },
        status: 'ACTIVE',
      },
      include: { salaryStructure: true },
    });
    if (!user) {
      throw new NotFoundException('Employee not found or inactive');
    }
    if (!user.salaryStructure) {
      throw new BadRequestException(
        'Salary structure missing — configure CTC breakup first',
      );
    }
    return user;
  }
}

function roundMonthlyCtc(s: {
  basicMonthly: { toString(): string };
  hraMonthly: { toString(): string };
  specialAllowanceMonthly: { toString(): string };
  conveyanceMonthly: { toString(): string };
  medicalMonthly: { toString(): string };
}): number {
  return (
    toNumber(s.basicMonthly) +
    toNumber(s.hraMonthly) +
    toNumber(s.specialAllowanceMonthly) +
    toNumber(s.conveyanceMonthly) +
    toNumber(s.medicalMonthly)
  );
}

/** Credit day falls in the month after the payroll month (e.g. September slip → 3 October). */
function creditDate(year: number, month: number, creditDay?: number | null): Date {
  const day = Math.min(Math.max(creditDay ?? 1, 1), 28);
  return new Date(year, month, day);
}

function roundMoney(n: number): number {
  return Math.round(n * 100) / 100;
}
