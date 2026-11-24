import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { LeaveStatus, LeaveType, Prisma } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { AppRole } from '../../common/enums/role.enum';
import { JwtPayload } from '../auth/interfaces/jwt-payload.interface';
import {
  canManageUser,
  visibleUsersWhere,
} from '../users/user-visibility.util';
import { AuditService } from '../audit/audit.service';
import { indianHolidaysForYear } from './indian-holidays';
import {
  ApplyLeaveDto,
  ReviewLeaveDto,
  UpsertHolidayDto,
  UpsertLeaveQuotaDto,
} from './dto/apply-leave.dto';

function parseDateOnly(value: string): Date {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(value.trim());
  if (!m) throw new BadRequestException('Invalid date (use YYYY-MM-DD)');
  return new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
}

function inclusiveDays(start: Date, end: Date): number {
  const ms = end.getTime() - start.getTime();
  if (ms < 0) return -1;
  return Math.floor(ms / 86_400_000) + 1;
}

@Injectable()
export class LeaveService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async ensureHolidaysSeeded(year: number) {
    const count = await this.prisma.companyHoliday.count({ where: { year } });
    if (count > 0) return;
    const seed = indianHolidaysForYear(year);
    if (!seed.length) return;
    await this.prisma.companyHoliday.createMany({
      data: seed.map((h) => ({
        id: randomUUID(),
        date: parseDateOnly(h.date),
        name: h.name,
        year,
        isNational: true,
      })),
      skipDuplicates: true,
    });
  }

  async myBalance(actor: JwtPayload, year?: number) {
    const y = year ?? new Date().getFullYear();
    return this.balanceForUser(actor.sub, y);
  }

  async balanceForUser(userId: string, year: number) {
    const quota = await this.prisma.leaveQuota.findUnique({
      where: { userId_year: { userId, year } },
    });
    const used = await this.prisma.leaveRequest.aggregate({
      where: {
        userId,
        status: LeaveStatus.APPROVED,
        startDate: {
          gte: new Date(Date.UTC(year, 0, 1)),
          lt: new Date(Date.UTC(year + 1, 0, 1)),
        },
        type: { not: LeaveType.UNPAID },
      },
      _sum: { days: true },
    });
    const pending = await this.prisma.leaveRequest.aggregate({
      where: {
        userId,
        status: LeaveStatus.PENDING,
        startDate: {
          gte: new Date(Date.UTC(year, 0, 1)),
          lt: new Date(Date.UTC(year + 1, 0, 1)),
        },
        type: { not: LeaveType.UNPAID },
      },
      _sum: { days: true },
    });
    const total = quota?.totalDays ?? 0;
    const usedDays = used._sum.days ?? 0;
    const pendingDays = pending._sum.days ?? 0;
    return {
      year,
      totalDays: total,
      usedDays,
      pendingDays,
      remainingDays: Math.max(0, total - usedDays),
      hasQuota: !!quota,
    };
  }

  async myRequests(actor: JwtPayload) {
    return this.prisma.leaveRequest.findMany({
      where: { userId: actor.sub },
      orderBy: [{ startDate: 'desc' }, { createdAt: 'desc' }],
      include: {
        reviewedBy: {
          select: { id: true, firstName: true, lastName: true, email: true },
        },
      },
    });
  }

  async apply(actor: JwtPayload, dto: ApplyLeaveDto) {
    if (actor.role !== AppRole.EMPLOYEE && actor.role !== AppRole.HR_ADMIN) {
      // HR can apply on behalf? For MVP only EMPLOYEE self-applies; HR uses admin path.
    }
    if (actor.role !== AppRole.EMPLOYEE) {
      throw new ForbiddenException('Only employees apply for leave here');
    }

    const start = parseDateOnly(dto.startDate);
    const end = parseDateOnly(dto.endDate);
    const days = inclusiveDays(start, end);
    if (days < 1) {
      throw new BadRequestException('End date must be on or after start date');
    }

    const year = start.getUTCFullYear();
    if (dto.type !== LeaveType.UNPAID) {
      const bal = await this.balanceForUser(actor.sub, year);
      if (!bal.hasQuota) {
        throw new BadRequestException(
          'No leave quota set for this year. Ask HR to assign your leave days.',
        );
      }
      if (bal.remainingDays - bal.pendingDays < days) {
        throw new BadRequestException(
          `Not enough leave balance (remaining ${bal.remainingDays}, pending ${bal.pendingDays}, requested ${days})`,
        );
      }
    }

    const row = await this.prisma.leaveRequest.create({
      data: {
        id: randomUUID(),
        userId: actor.sub,
        type: dto.type,
        startDate: start,
        endDate: end,
        days,
        reason: dto.reason?.trim() || null,
        status: LeaveStatus.PENDING,
      },
    });

    await this.audit.write({
      actorId: actor.sub,
      actorEmail: actor.email,
      actorRole: actor.role,
      action: 'LEAVE_APPLY',
      entity: 'leave_request',
      entityId: row.id,
      summary: `Leave ${dto.type} ${dto.startDate}→${dto.endDate} (${days}d)`,
    });

    return row;
  }

  async cancelMine(actor: JwtPayload, id: string) {
    const row = await this.prisma.leaveRequest.findUnique({ where: { id } });
    if (!row || row.userId !== actor.sub) {
      throw new NotFoundException('Leave request not found');
    }
    if (row.status !== LeaveStatus.PENDING) {
      throw new BadRequestException('Only pending requests can be cancelled');
    }
    return this.prisma.leaveRequest.update({
      where: { id },
      data: { status: LeaveStatus.CANCELLED },
    });
  }

  async listPending(actor: JwtPayload) {
    return this.prisma.leaveRequest.findMany({
      where: {
        status: LeaveStatus.PENDING,
        user: visibleUsersWhere(actor),
      },
      orderBy: { createdAt: 'asc' },
      include: {
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            employeeCode: true,
          },
        },
      },
    });
  }

  async listAll(actor: JwtPayload, status?: LeaveStatus) {
    return this.prisma.leaveRequest.findMany({
      where: {
        ...(status ? { status } : {}),
        user: visibleUsersWhere(actor),
      },
      orderBy: [{ createdAt: 'desc' }],
      take: 200,
      include: {
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            employeeCode: true,
          },
        },
        reviewedBy: {
          select: { id: true, firstName: true, lastName: true },
        },
      },
    });
  }

  async review(actor: JwtPayload, id: string, dto: ReviewLeaveDto) {
    const row = await this.prisma.leaveRequest.findUnique({
      where: { id },
      include: { user: true },
    });
    if (!row) throw new NotFoundException('Leave request not found');
    if (!canManageUser(actor, row.user)) {
      throw new ForbiddenException('Cannot review this leave request');
    }
    if (row.status !== LeaveStatus.PENDING) {
      throw new BadRequestException('Request is not pending');
    }

    const updated = await this.prisma.leaveRequest.update({
      where: { id },
      data: {
        status:
          dto.status === 'APPROVED'
            ? LeaveStatus.APPROVED
            : LeaveStatus.REJECTED,
        reviewedById: actor.sub,
        reviewedAt: new Date(),
        reviewNote: dto.reviewNote?.trim() || null,
      },
    });

    await this.audit.write({
      actorId: actor.sub,
      actorEmail: actor.email,
      actorRole: actor.role,
      action: dto.status === 'APPROVED' ? 'LEAVE_APPROVE' : 'LEAVE_REJECT',
      entity: 'leave_request',
      entityId: id,
      summary: `${dto.status} leave for ${row.user.email}`,
    });

    return updated;
  }

  async upsertQuota(
    actor: JwtPayload,
    userId: string,
    dto: UpsertLeaveQuotaDto,
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || user.role === 'SUPER_ADMIN') {
      throw new NotFoundException('Employee not found');
    }
    if (!canManageUser(actor, user)) {
      throw new ForbiddenException('Cannot set leave quota for this user');
    }
    if (!Number.isInteger(dto.year) || dto.year < 2020 || dto.year > 2100) {
      throw new BadRequestException('Invalid year');
    }
    if (
      !Number.isFinite(dto.totalDays) ||
      dto.totalDays < 0 ||
      dto.totalDays > 366
    ) {
      throw new BadRequestException('totalDays must be 0–366');
    }

    const quota = await this.prisma.leaveQuota.upsert({
      where: { userId_year: { userId, year: dto.year } },
      create: {
        id: randomUUID(),
        userId,
        year: dto.year,
        totalDays: Math.trunc(dto.totalDays),
      },
      update: { totalDays: Math.trunc(dto.totalDays) },
    });

    await this.audit.write({
      actorId: actor.sub,
      actorEmail: actor.email,
      actorRole: actor.role,
      action: 'LEAVE_QUOTA_SET',
      entity: 'leave_quota',
      entityId: quota.id,
      summary: `Set ${dto.totalDays} leave days for ${user.email} (${dto.year})`,
    });

    return { ...quota, balance: await this.balanceForUser(userId, dto.year) };
  }

  async getQuota(actor: JwtPayload, userId: string, year?: number) {
    const y = year ?? new Date().getFullYear();
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('Employee not found');
    if (!canManageUser(actor, user)) {
      throw new ForbiddenException('Cannot view leave quota');
    }
    return this.balanceForUser(userId, y);
  }

  async calendar(
    actor: JwtPayload,
    year: number,
    month: number,
    userId?: string,
  ) {
    if (month < 1 || month > 12) {
      throw new BadRequestException('Invalid month');
    }
    await this.ensureHolidaysSeeded(year);

    const rangeStart = new Date(Date.UTC(year, month - 1, 1));
    const rangeEnd = new Date(Date.UTC(year, month, 0));

    const holidays = await this.prisma.companyHoliday.findMany({
      where: {
        date: { gte: rangeStart, lte: rangeEnd },
      },
      orderBy: { date: 'asc' },
    });

    let targetUserId = actor.sub;
    if (userId && userId !== actor.sub) {
      if (
        actor.role !== AppRole.HR_ADMIN &&
        actor.role !== AppRole.SUPER_ADMIN
      ) {
        throw new ForbiddenException();
      }
      const user = await this.prisma.user.findUnique({ where: { id: userId } });
      if (!user || !canManageUser(actor, user)) {
        throw new ForbiddenException();
      }
      targetUserId = userId;
    } else if (
      actor.role === AppRole.HR_ADMIN ||
      actor.role === AppRole.SUPER_ADMIN
    ) {
      // Admin viewing own calendar — still fine; team leaves optional via userId
      targetUserId = userId ?? actor.sub;
    }

    const leaves = await this.prisma.leaveRequest.findMany({
      where: {
        userId: targetUserId,
        status: { in: [LeaveStatus.APPROVED, LeaveStatus.PENDING] },
        startDate: { lte: rangeEnd },
        endDate: { gte: rangeStart },
      },
      orderBy: { startDate: 'asc' },
    });

    // For HR home calendar without userId: show all visible approved/pending leaves in month
    let teamLeaves: Prisma.LeaveRequestGetPayload<{
      include: {
        user: {
          select: {
            id: true;
            firstName: true;
            lastName: true;
            employeeCode: true;
          };
        };
      };
    }>[] = [];
    if (
      !userId &&
      (actor.role === AppRole.HR_ADMIN || actor.role === AppRole.SUPER_ADMIN)
    ) {
      teamLeaves = await this.prisma.leaveRequest.findMany({
        where: {
          status: { in: [LeaveStatus.APPROVED, LeaveStatus.PENDING] },
          startDate: { lte: rangeEnd },
          endDate: { gte: rangeStart },
          user: visibleUsersWhere(actor),
        },
        orderBy: { startDate: 'asc' },
        include: {
          user: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              employeeCode: true,
            },
          },
        },
      });
    }

    return {
      year,
      month,
      holidays,
      leaves,
      teamLeaves,
      balance:
        actor.role === AppRole.EMPLOYEE
          ? await this.balanceForUser(actor.sub, year)
          : userId
            ? await this.balanceForUser(targetUserId, year)
            : null,
    };
  }

  async listHolidays(year: number) {
    await this.ensureHolidaysSeeded(year);
    return this.prisma.companyHoliday.findMany({
      where: { year },
      orderBy: { date: 'asc' },
    });
  }

  async upsertHoliday(actor: JwtPayload, dto: UpsertHolidayDto) {
    const date = parseDateOnly(dto.date);
    const year = date.getUTCFullYear();
    const name = dto.name.trim();
    if (!name) throw new BadRequestException('Holiday name required');

    const existing = await this.prisma.companyHoliday.findFirst({
      where: { date, name },
    });
    if (existing) {
      return this.prisma.companyHoliday.update({
        where: { id: existing.id },
        data: { isNational: dto.isNational ?? existing.isNational },
      });
    }
    return this.prisma.companyHoliday.create({
      data: {
        id: randomUUID(),
        date,
        name,
        year,
        isNational: dto.isNational ?? false,
      },
    });
  }

  async deleteHoliday(id: string) {
    try {
      await this.prisma.companyHoliday.delete({ where: { id } });
      return { ok: true };
    } catch {
      throw new NotFoundException('Holiday not found');
    }
  }
}
