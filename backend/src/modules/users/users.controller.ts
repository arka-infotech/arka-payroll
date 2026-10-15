import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { CreateEmployeeDto } from './dto/create-employee.dto';
import { UpsertSalaryStructureDto } from './dto/upsert-salary-structure.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { AppRole } from '../../common/enums/role.enum';

@Controller('users')
@UseGuards(JwtAuthGuard, RolesGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  /** HR / Super Admin: list employees — Super Admin never appears in results. */
  @Get()
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  list() {
    return this.usersService.listVisibleUsers();
  }

  @Get(':id')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  getOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.usersService.findVisibleById(id);
  }

  @Post()
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  create(@Body() dto: CreateEmployeeDto) {
    return this.usersService.createEmployee(dto);
  }

  @Put(':id/salary-structure')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  upsertStructure(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpsertSalaryStructureDto,
  ) {
    return this.usersService.upsertSalaryStructure(id, dto);
  }
}
