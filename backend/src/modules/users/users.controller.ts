import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { CreateEmployeeDto } from './dto/create-employee.dto';
import { UpdateEmployeeDto } from './dto/update-employee.dto';
import { SelfUpdateProfileDto } from './dto/self-update.dto';
import { UpsertSalaryStructureDto } from './dto/upsert-salary-structure.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { AppRole } from '../../common/enums/role.enum';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/interfaces/jwt-payload.interface';
import { IsOptional, IsString, MaxLength } from 'class-validator';

class BanUserDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

@Controller('users')
@UseGuards(JwtAuthGuard, RolesGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  /** HR / Super Admin: list employees — Super Admin never appears. Presence only for Super. */
  @Get()
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  list(@CurrentUser() user: JwtPayload) {
    return this.usersService.listVisibleUsers(user);
  }

  /** Employee: own profile (bank / statutory completion). */
  @Get('me/profile')
  @Roles(AppRole.EMPLOYEE, AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  myProfile(@CurrentUser() user: JwtPayload) {
    return this.usersService.getOwnProfile(user.sub);
  }

  @Patch('me/profile')
  @Roles(AppRole.EMPLOYEE)
  updateMyProfile(
    @CurrentUser() user: JwtPayload,
    @Body() dto: SelfUpdateProfileDto,
  ) {
    return this.usersService.selfUpdateProfile(user.sub, dto);
  }

  @Get(':id')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN, AppRole.EMPLOYEE)
  getOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    if (user.role === AppRole.EMPLOYEE) {
      return this.usersService.getOwnProfile(user.sub === id ? id : user.sub);
    }
    return this.usersService.findVisibleById(id, user);
  }

  @Post()
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  create(@Body() dto: CreateEmployeeDto, @CurrentUser() user: JwtPayload) {
    return this.usersService.createEmployee(dto, user);
  }

  @Patch(':id')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateEmployeeDto,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.usersService.updateEmployee(id, dto, user);
  }

  @Put(':id/salary-structure')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  upsertStructure(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpsertSalaryStructureDto,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.usersService.upsertSalaryStructure(id, dto, user);
  }

  @Post(':id/ban')
  @Roles(AppRole.SUPER_ADMIN)
  ban(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: BanUserDto,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.usersService.banUser(id, dto.reason, user);
  }

  @Post(':id/unban')
  @Roles(AppRole.SUPER_ADMIN)
  unban(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.usersService.unbanUser(id, user);
  }

  @Delete(':id')
  @Roles(AppRole.SUPER_ADMIN)
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.usersService.removeUser(id, user);
  }
}
