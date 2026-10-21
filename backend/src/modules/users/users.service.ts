import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  forwardRef,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
import { Role } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { AppRole } from '../../common/enums/role.enum';
import { CreateEmployeeDto } from './dto/create-employee.dto';
import { UpdateEmployeeDto } from './dto/update-employee.dto';
import { UpsertSalaryStructureDto } from './dto/upsert-salary-structure.dto';
import { AuditService } from '../audit/audit.service';
import { JwtPayload } from '../auth/interfaces/jwt-payload.interface';
import {
  canManageUser,
  visibleUsersWhere,
} from './user-visibility.util';
import { PayrollService } from '../payroll/payroll.service';

/** Base fields returned to HR (no presence / audit metadata). */
const USER_HR_SELECT = {
  id: true,
  email: true,
  role: true,
  employeeCode: true,
  firstName: true,
  lastName: true,
  designation: true,
  dateOfJoining: true,
  status: true,
  pan: true,
  aadhaar: true,
  uan: true,
  bankName: true,
  bankAccountNumber: true,
  bankIfsc: true,
  createdAt: true,
  salaryStructure: true,
} as const;

/** Super Admin also receives online presence fields. */
const USER_SUPER_SELECT = {
  ...USER_HR_SELECT,
  lastSeenAt: true,
  bannedAt: true,
  bannedReason: true,
  updatedAt: true,
} as const;

const ONLINE_THRESHOLD_MS = 2 * 60 * 1000;

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    @Inject(forwardRef(() => PayrollService))
    private readonly payroll: PayrollService,
  ) {}

  /**
   * HR + Super Admin lists exclude Super Admin; HR admins see each other.
   * Presence (`isOnline`) is only attached for Super Admin viewers.
   */
  async listVisibleUsers(requester: JwtPayload) {
    const isSuper = requester.role === AppRole.SUPER_ADMIN;
    const rows = await this.prisma.user.findMany({
      where: visibleUsersWhere(requester),
      select: isSuper ? USER_SUPER_SELECT : USER_HR_SELECT,
      orderBy: [{ role: 'asc' }, { firstName: 'asc' }],
    });

    if (!isSuper) {
      return rows;
    }

    const now = Date.now();
    return rows.map((u) => {
      const lastSeen = 'lastSeenAt' in u ? (u as { lastSeenAt?: Date | null }).lastSeenAt : null;
      return {
        ...u,
        isOnline: !!lastSeen && now - lastSeen.getTime() < ONLINE_THRESHOLD_MS,
      };
    });
  }

  async findVisibleById(id: string, requester?: JwtPayload) {
    const isSuper = requester?.role === AppRole.SUPER_ADMIN;
    const user = await this.prisma.user.findFirst({
      where: { id, role: { not: Role.SUPER_ADMIN } },
      select: isSuper ? USER_SUPER_SELECT : USER_HR_SELECT,
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    if (requester && !canManageUser(requester, user)) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  /**
   * Super Admin may create unlimited employees.
   * Admin access (HR_ADMIN) accounts may be created without a fixed slot cap.
   * SUPER_ADMIN remains seed-only.
   */
  async createEmployee(dto: CreateEmployeeDto, actor: JwtPayload) {
    if (dto.role === (AppRole.SUPER_ADMIN as string)) {
      throw new BadRequestException(
        'SUPER_ADMIN cannot be created via API — seed only',
      );
    }

    const email = dto.email.toLowerCase().trim();
    const exists = await this.prisma.user.findUnique({ where: { email } });
    if (exists) {
      throw new ConflictException('Email already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);

    const created = await this.prisma.user.create({
      data: {
        id: randomUUID(),
        email,
        passwordHash,
        role: dto.role as Role,
        firstName: dto.firstName.trim(),
        lastName: dto.lastName.trim(),
        employeeCode: normalizeEmployeeCode(dto.employeeCode),
        designation: dto.designation.trim(),
        dateOfJoining: new Date(dto.dateOfJoining),
        pan: dto.pan.trim().toUpperCase(),
        aadhaar: asNa(dto.aadhaar),
        uan: asNa(dto.uan),
        bankName: dto.bankName.trim(),
        bankAccountNumber: dto.bankAccountNumber.trim(),
        bankIfsc: dto.bankIfsc.trim().toUpperCase(),
        createdById: actor.sub,
      },
      select: USER_HR_SELECT,
    });

    await this.audit.write({
      actorId: actor.sub,
      actorEmail: actor.email,
      actorRole: actor.role,
      action: 'USER_CREATE',
      entity: 'user',
      entityId: created.id,
      summary: `Created ${created.role} ${created.email}`,
    });

    return created;
  }

  async updateEmployee(
    userId: string,
    dto: UpdateEmployeeDto,
    actor: JwtPayload,
  ) {
    const existing = await this.findVisibleById(userId, actor);

    if (dto.role === (AppRole.SUPER_ADMIN as string)) {
      throw new BadRequestException(
        'SUPER_ADMIN cannot be assigned via API — seed only',
      );
    }

    let email = existing.email;
    if (dto.email !== undefined) {
      email = dto.email.toLowerCase().trim();
      if (email !== existing.email) {
        const clash = await this.prisma.user.findUnique({ where: { email } });
        if (clash) {
          throw new ConflictException('Email already registered');
        }
      }
    }

    const data: Record<string, unknown> = {};
    if (dto.email !== undefined) data.email = email;
    if (dto.firstName !== undefined) data.firstName = dto.firstName.trim();
    if (dto.lastName !== undefined) data.lastName = dto.lastName.trim();
    if (dto.employeeCode !== undefined) {
      data.employeeCode = normalizeEmployeeCode(dto.employeeCode);
    }
    if (dto.designation !== undefined) {
      data.designation = dto.designation.trim();
    }
    if (dto.dateOfJoining !== undefined) {
      data.dateOfJoining = new Date(dto.dateOfJoining);
    }
    if (dto.role !== undefined) data.role = dto.role as Role;
    if (dto.pan !== undefined) data.pan = dto.pan.trim().toUpperCase();
    if (dto.aadhaar !== undefined) data.aadhaar = asNa(dto.aadhaar);
    if (dto.uan !== undefined) data.uan = asNa(dto.uan);
    if (dto.bankName !== undefined) data.bankName = dto.bankName.trim();
    if (dto.bankAccountNumber !== undefined) {
      data.bankAccountNumber = dto.bankAccountNumber.trim();
    }
    if (dto.bankIfsc !== undefined) {
      data.bankIfsc = dto.bankIfsc.trim().toUpperCase();
    }
    if (dto.password !== undefined && dto.password.trim().length > 0) {
      data.passwordHash = await bcrypt.hash(dto.password, 12);
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data,
      select: USER_HR_SELECT,
    });

    await this.audit.write({
      actorId: actor.sub,
      actorEmail: actor.email,
      actorRole: actor.role,
      action: 'USER_UPDATE',
      entity: 'user',
      entityId: updated.id,
      summary: `Updated profile ${updated.email}`,
    });

    return updated;
  }

  async upsertSalaryStructure(
    userId: string,
    dto: UpsertSalaryStructureDto,
    actor: JwtPayload,
  ) {
    await this.findVisibleById(userId, actor);

    const flex = dto.flexBreakup ?? true;
    const monthlyComponents =
      dto.basicMonthly +
      dto.hraMonthly +
      dto.specialAllowanceMonthly +
      (dto.conveyanceMonthly ?? 0) +
      (dto.medicalMonthly ?? 0);
    const monthlyFromCtc = dto.annualCtc / 12;

    if (flex) {
      if (Math.abs(monthlyComponents - monthlyFromCtc) > 1) {
        throw new BadRequestException(
          'Monthly components must equal annual CTC ÷ 12 (within ₹1)',
        );
      }
    } else {
      const annualBasic = dto.basicMonthly * 12;
      const basicPct = annualBasic / dto.annualCtc;
      if (basicPct < 0.4 || basicPct > 0.5) {
        throw new BadRequestException(
          'Basic Salary must be 40–50% of annual CTC',
        );
      }
      if (dto.basicMonthly <= 0) {
        throw new BadRequestException('Basic monthly must be greater than zero');
      }
      const hraPct = dto.hraMonthly / dto.basicMonthly;
      if (hraPct < 0.4 || hraPct > 0.5) {
        throw new BadRequestException('HRA must be 40–50% of Basic Salary');
      }
    }

    const structure = await this.prisma.salaryStructure.upsert({
      where: { userId },
      create: {
        id: randomUUID(),
        userId,
        annualCtc: dto.annualCtc,
        basicMonthly: dto.basicMonthly,
        hraMonthly: dto.hraMonthly,
        specialAllowanceMonthly: dto.specialAllowanceMonthly,
        conveyanceMonthly: dto.conveyanceMonthly ?? 0,
        medicalMonthly: dto.medicalMonthly ?? 0,
        epfApplicable: dto.epfApplicable ?? false,
        esicApplicable: dto.esicApplicable ?? false,
        flexBreakup: dto.flexBreakup ?? true,
        professionalTaxApplicable: dto.professionalTaxApplicable ?? false,
        tdsApplicable: dto.tdsApplicable ?? false,
        salaryCreditDay: dto.salaryCreditDay ?? 1,
        taxRegime: dto.taxRegime ?? 'NEW',
        effectiveFrom: new Date(dto.effectiveFrom),
      },
      update: {
        annualCtc: dto.annualCtc,
        basicMonthly: dto.basicMonthly,
        hraMonthly: dto.hraMonthly,
        specialAllowanceMonthly: dto.specialAllowanceMonthly,
        conveyanceMonthly: dto.conveyanceMonthly ?? 0,
        medicalMonthly: dto.medicalMonthly ?? 0,
        epfApplicable: dto.epfApplicable ?? false,
        esicApplicable: dto.esicApplicable ?? false,
        flexBreakup: dto.flexBreakup ?? true,
        professionalTaxApplicable: dto.professionalTaxApplicable ?? false,
        tdsApplicable: dto.tdsApplicable ?? false,
        salaryCreditDay: dto.salaryCreditDay ?? 1,
        taxRegime: dto.taxRegime ?? 'NEW',
        effectiveFrom: new Date(dto.effectiveFrom),
      },
    });

    const now = new Date();
    await this.payroll.materializeDraftForUser(
      userId,
      now.getFullYear(),
      now.getMonth() + 1,
    );

    await this.audit.write({
      actorId: actor.sub,
      actorEmail: actor.email,
      actorRole: actor.role,
      action: 'SALARY_STRUCTURE_UPSERT',
      entity: 'salary_structure',
      entityId: structure.id,
      summary: `Updated salary structure for user ${userId}`,
      metadata: { annualCtc: dto.annualCtc },
    });

    return structure;
  }

  /** Super Admin only — ban / unban. */
  async banUser(
    userId: string,
    reason: string | undefined,
    actor: JwtPayload,
  ) {
    if (actor.role !== AppRole.SUPER_ADMIN) {
      throw new ForbiddenException('You do not have permission to ban users');
    }
    const user = await this.findVisibleById(userId, actor);
    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: {
        status: 'BANNED',
        bannedAt: new Date(),
        bannedReason: reason ?? 'Banned by an administrator',
      },
      select: USER_SUPER_SELECT,
    });
    await this.audit.write({
      actorId: actor.sub,
      actorEmail: actor.email,
      actorRole: actor.role,
      action: 'USER_BAN',
      entity: 'user',
      entityId: userId,
      summary: `Banned ${user.email}`,
      metadata: { reason },
    });
    return updated;
  }

  async unbanUser(userId: string, actor: JwtPayload) {
    if (actor.role !== AppRole.SUPER_ADMIN) {
      throw new ForbiddenException('You do not have permission to unban users');
    }
    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: {
        status: 'ACTIVE',
        bannedAt: null,
        bannedReason: null,
      },
      select: USER_SUPER_SELECT,
    });
    await this.audit.write({
      actorId: actor.sub,
      actorEmail: actor.email,
      actorRole: actor.role,
      action: 'USER_UNBAN',
      entity: 'user',
      entityId: userId,
      summary: `Unbanned user ${userId}`,
    });
    return updated;
  }

  /** Super Admin only — hard remove (non–Super Admin). */
  async removeUser(userId: string, actor: JwtPayload) {
    if (actor.role !== AppRole.SUPER_ADMIN) {
      throw new ForbiddenException('You do not have permission to remove users');
    }
    const user = await this.findVisibleById(userId, actor);
    await this.prisma.user.delete({ where: { id: userId } });
    await this.audit.write({
      actorId: actor.sub,
      actorEmail: actor.email,
      actorRole: actor.role,
      action: 'USER_DELETE',
      entity: 'user',
      entityId: userId,
      summary: `Removed ${user.email}`,
    });
    return { deleted: true, id: userId };
  }

  async touchPresence(userId: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { lastSeenAt: new Date() },
    });
  }
}

/** Empty optional text becomes N/A on the profile. */
function asNa(value?: string | null): string {
  const t = value?.trim();
  return t && t.length > 0 ? t : 'N/A';
}

function normalizeEmployeeCode(code: string): string {
  const t = code.trim().toUpperCase();
  if (!t.startsWith('AISS')) {
    throw new BadRequestException('Employee ID must start with AISS');
  }
  return t;
}
