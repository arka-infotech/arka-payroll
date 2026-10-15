import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { AuditService } from './audit.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { AppRole } from '../../common/enums/role.enum';

@Controller('audit')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AuditController {
  constructor(private readonly audit: AuditService) {}

  /** Super Admin only — who changed what. */
  @Get()
  @Roles(AppRole.SUPER_ADMIN)
  list(@Query('limit') limit?: string) {
    return this.audit.list(limit ? Number(limit) : 100);
  }
}
