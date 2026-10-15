import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
import { Role } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { AppRole } from '../../common/enums/role.enum';
import { CreateEmployeeDto } from './dto/create-employee.dto';
import { UpsertSalaryStructureDto } from './dto/upsert-salary-structure.dto';

/** Fields safe to return to UI (never exposes passwordHash). */
const USER_PUBLIC_SELECT = {
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

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Standard user list for HR / dashboards.
   * Explicitly excludes SUPER_ADMIN (hidden root) from every array returned to the UI.
   */
  async listVisibleUsers() {
    return this.prisma.user.findMany({
      where: { role: { not: Role.SUPER_ADMIN } },
      select: USER_PUBLIC_SELECT,
      orderBy: [{ role: 'asc' }, { firstName: 'asc' }],
    });
  }

  async findVisibleById(id: string) {
    const user = await this.prisma.user.findFirst({
      where: { id, role: { not: Role.SUPER_ADMIN } },
      select: USER_PUBLIC_SELECT,
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  async createEmployee(dto: CreateEmployeeDto) {
    if (dto.role === (AppRole.SUPER_ADMIN as string)) {
      throw new BadRequestException(
        'SUPER_ADMIN cannot be created via API — seed only',
      );
    }

    if (dto.role === AppRole.HR_ADMIN) {
      const activeHr = await this.prisma.user.count({
        where: { role: Role.HR_ADMIN, status: 'ACTIVE' },
      });
      if (activeHr >= 2) {
        throw new ConflictException(
          'HR Admin active slot limit (2) already reached',
        );
      }
    }

    const email = dto.email.toLowerCase().trim();
    const exists = await this.prisma.user.findUnique({ where: { email } });
    if (exists) {
      throw new ConflictException('Email already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);

    return this.prisma.user.create({
      data: {
        id: randomUUID(),
        email,
        passwordHash,
        role: dto.role as Role,
        firstName: dto.firstName,
        lastName: dto.lastName,
        employeeCode: dto.employeeCode,
        designation: dto.designation,
        dateOfJoining: dto.dateOfJoining
          ? new Date(dto.dateOfJoining)
          : undefined,
        pan: dto.pan,
        aadhaar: dto.aadhaar,
        uan: dto.uan,
        bankName: dto.bankName,
        bankAccountNumber: dto.bankAccountNumber,
        bankIfsc: dto.bankIfsc,
      },
      select: USER_PUBLIC_SELECT,
    });
  }

  async upsertSalaryStructure(userId: string, dto: UpsertSalaryStructureDto) {
    await this.findVisibleById(userId);

    const annualBasic = dto.basicMonthly * 12;
    const basicPct = annualBasic / dto.annualCtc;
    if (basicPct < 0.4 || basicPct > 0.5) {
      throw new BadRequestException(
        'Basic Salary must be 40–50% of annual CTC',
      );
    }

    const hraPct = dto.hraMonthly / dto.basicMonthly;
    if (hraPct < 0.4 || hraPct > 0.5) {
      throw new BadRequestException('HRA must be 40–50% of Basic Salary');
    }

    return this.prisma.salaryStructure.upsert({
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
        epfApplicable: dto.epfApplicable ?? true,
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
        epfApplicable: dto.epfApplicable ?? true,
        taxRegime: dto.taxRegime ?? 'NEW',
        effectiveFrom: new Date(dto.effectiveFrom),
      },
    });
  }
}
