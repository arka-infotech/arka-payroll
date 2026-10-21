import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { AppRole } from '../../common/enums/role.enum';
import { LoginDto } from './dto/login.dto';
import { JwtPayload } from './interfaces/jwt-payload.interface';
import { AuditService } from '../audit/audit.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly audit: AuditService,
  ) {}

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase().trim() },
    });

    if (!user || user.status === 'BANNED' || user.status === 'TERMINATED') {
      throw new UnauthorizedException('Invalid credentials');
    }
    if (user.status !== 'ACTIVE') {
      throw new UnauthorizedException('Account inactive');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // App is admin-only — employees have profiles for payroll, not app login.
    if (user.role === AppRole.EMPLOYEE) {
      throw new UnauthorizedException(
        'Employee login is disabled. Use an Admin account to sign in.',
      );
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastSeenAt: new Date() },
    });

    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      role: user.role as AppRole,
      employeeCode: user.employeeCode,
    };

    await this.audit.write({
      actorId: user.id,
      actorEmail: user.email,
      actorRole: user.role as AppRole,
      action: 'AUTH_LOGIN',
      entity: 'user',
      entityId: user.id,
      summary: `Login ${user.email}`,
    });

    return {
      accessToken: await this.jwt.signAsync(payload),
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        firstName: user.firstName,
        lastName: user.lastName,
        employeeCode: user.employeeCode,
        designation: user.designation,
      },
    };
  }

  async me(userId: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { lastSeenAt: new Date() },
    });

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        role: true,
        firstName: true,
        lastName: true,
        employeeCode: true,
        designation: true,
        status: true,
      },
    });
    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException();
    }
    if (user.role === AppRole.EMPLOYEE) {
      throw new UnauthorizedException(
        'Employee login is disabled. Use an Admin account to sign in.',
      );
    }
    return user;
  }

  async heartbeat(userId: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { lastSeenAt: new Date() },
    });
    return { ok: true };
  }
}
