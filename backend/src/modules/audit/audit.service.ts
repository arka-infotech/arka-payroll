import { Injectable } from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { AppRole } from '../../common/enums/role.enum';

export interface AuditWriteInput {
  actorId?: string;
  actorEmail?: string;
  actorRole?: AppRole | Role;
  action: string;
  entity: string;
  entityId?: string;
  summary: string;
  metadata?: Record<string, unknown>;
  ipAddress?: string;
}

@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async write(input: AuditWriteInput): Promise<void> {
    try {
      await this.prisma.auditLog.create({
        data: {
          id: randomUUID(),
          actorId: input.actorId,
          actorEmail: input.actorEmail,
          actorRole: (input.actorRole as Role) ?? null,
          action: input.action,
          entity: input.entity,
          entityId: input.entityId,
          summary: input.summary,
          metadata: (input.metadata ?? undefined) as
            | Prisma.InputJsonValue
            | undefined,
          ipAddress: input.ipAddress,
        },
      });
    } catch (err) {
      // Never block primary flows on audit failure
      console.error('[audit] write failed', err);
    }
  }

  list(limit = 100) {
    return this.prisma.auditLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: Math.min(limit, 500),
    });
  }
}
