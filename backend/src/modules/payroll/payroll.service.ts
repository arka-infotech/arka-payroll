import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PayrollStatus, Prisma, Role } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { AppRole } from '../../common/enums/role.enum';
import { ProcessPayrollDto } from './dto/process-payroll.dto';
import {
  buildTrackingReference,
  computeMonthlyPayroll,
} from './domain/payroll-calculator';
import { toNumber } from './domain/money.util';
import { PdfSlipService } from './pdf-slip.service';

@Injectable()
export class PayrollService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pdfSlip: PdfSlipService,
  ) {}

  /**
   * Process a single employee's monthly payroll inside a strict SQL transaction.
   * Prevents partial writes / race conditions on the unique (userId, year, month) key.
   */
  async processMonthly(
    dto: ProcessPayrollDto,
    processedBy: string,
  ) {
    const user = await this.prisma.user.findFirst({
      where: {
        id: dto.userId,
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

    const existing = await this.prisma.monthlyPayroll.findUnique({
      where: {
        userId_year_month: {
          userId: dto.userId,
          year: dto.year,
          month: dto.month,
        },
      },
    });

    if (
      existing &&
      (existing.status === PayrollStatus.LOCKED ||
        existing.status === PayrollStatus.PAID)
    ) {
      throw new BadRequestException(
        `Payroll for ${dto.year}-${dto.month} is ${existing.status} and cannot be reprocessed`,
      );
    }

    const computed = computeMonthlyPayroll(user.salaryStructure, {
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

    const trackingReference = buildTrackingReference(
      dto.year,
      dto.month,
      user.employeeCode,
      user.id,
    );

    // ── Strict interactive transaction ──────────────────────────────────────
    return this.prisma.$transaction(async (tx) => {
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
        professionalTax: computed.professionalTax,
        tds: computed.tds,
        otherDeductions: computed.otherDeductions,
        totalDeductions: computed.totalDeductions,
        netPay: computed.netPay,
        trackingReference,
        status: PayrollStatus.PROCESSED,
        processedAt: new Date(),
        processedBy,
        calculationSnapshot: computed.snapshot as Prisma.InputJsonValue,
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
  }

  async processBatch(
    year: number,
    month: number,
    entries: ProcessPayrollDto[],
    processedBy: string,
  ) {
    const results = [];
    for (const entry of entries) {
      const row = await this.processMonthly(
        { ...entry, year, month },
        processedBy,
      );
      results.push(row);
    }
    return results;
  }

  async listForPeriod(year: number, month: number) {
    return this.prisma.monthlyPayroll.findMany({
      where: {
        year,
        month,
        user: { role: { not: Role.SUPER_ADMIN } },
      },
      include: {
        user: {
          select: {
            id: true,
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

  /**
   * Employees see only their own slips; HR/Super Admin may fetch any (non-root).
   */
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

    return row;
  }

  async listMySlips(userId: string) {
    return this.prisma.monthlyPayroll.findMany({
      where: {
        userId,
        status: { in: [PayrollStatus.PROCESSED, PayrollStatus.LOCKED, PayrollStatus.PAID] },
      },
      orderBy: [{ year: 'desc' }, { month: 'desc' }],
    });
  }

  async generatePdfBuffer(
    payrollId: string,
    requester: { sub: string; role: AppRole },
  ): Promise<{ buffer: Buffer; filename: string }> {
    const slip = await this.getSlipMeta(payrollId, requester);
    const buffer = await this.pdfSlip.renderA4(slip);
    const filename = `${slip.trackingReference}.pdf`;
    return { buffer, filename };
  }

  /** Helper used by HR dashboard grid — active employees without SUPER_ADMIN. */
  async listPayrollGridSeed(year: number, month: number) {
    const employees = await this.prisma.user.findMany({
      where: {
        role: { not: Role.SUPER_ADMIN },
        status: 'ACTIVE',
      },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        employeeCode: true,
        designation: true,
        salaryStructure: true,
        monthlyPayrolls: {
          where: { year, month },
          take: 1,
        },
      },
      orderBy: { firstName: 'asc' },
    });

    return employees.map((e) => ({
      userId: e.id,
      name: `${e.firstName} ${e.lastName}`,
      employeeCode: e.employeeCode,
      designation: e.designation,
      hasStructure: !!e.salaryStructure,
      monthlyCtc: e.salaryStructure
        ? roundMonthlyCtc(e.salaryStructure)
        : null,
      existingPayroll: e.monthlyPayrolls[0] ?? null,
    }));
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
