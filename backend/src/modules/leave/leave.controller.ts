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
  Query,
  UseGuards,
} from '@nestjs/common';
import { LeaveStatus } from '@prisma/client';
import { LeaveService } from './leave.service';
import {
  ApplyLeaveDto,
  ReviewLeaveDto,
  UpsertHolidayDto,
  UpsertLeaveQuotaDto,
} from './dto/apply-leave.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { AppRole } from '../../common/enums/role.enum';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/interfaces/jwt-payload.interface';

@Controller('leave')
@UseGuards(JwtAuthGuard, RolesGuard)
export class LeaveController {
  constructor(private readonly leave: LeaveService) {}

  @Get('me/balance')
  @Roles(AppRole.EMPLOYEE, AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  myBalance(
    @CurrentUser() user: JwtPayload,
    @Query('year') year?: string,
  ) {
    return this.leave.myBalance(user, year ? Number(year) : undefined);
  }

  @Get('me/requests')
  @Roles(AppRole.EMPLOYEE)
  myRequests(@CurrentUser() user: JwtPayload) {
    return this.leave.myRequests(user);
  }

  @Post('me/requests')
  @Roles(AppRole.EMPLOYEE)
  apply(@CurrentUser() user: JwtPayload, @Body() dto: ApplyLeaveDto) {
    return this.leave.apply(user, dto);
  }

  @Post('me/requests/:id/cancel')
  @Roles(AppRole.EMPLOYEE)
  cancel(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.leave.cancelMine(user, id);
  }

  @Get('calendar')
  @Roles(AppRole.EMPLOYEE, AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  calendar(
    @CurrentUser() user: JwtPayload,
    @Query('year') year: string,
    @Query('month') month: string,
    @Query('userId') userId?: string,
  ) {
    return this.leave.calendar(
      user,
      Number(year) || new Date().getFullYear(),
      Number(month) || new Date().getMonth() + 1,
      userId,
    );
  }

  @Get('holidays')
  @Roles(AppRole.EMPLOYEE, AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  holidays(@Query('year') year?: string) {
    return this.leave.listHolidays(
      year ? Number(year) : new Date().getFullYear(),
    );
  }

  @Get('pending')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  pending(@CurrentUser() user: JwtPayload) {
    return this.leave.listPending(user);
  }

  @Get('requests')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  all(
    @CurrentUser() user: JwtPayload,
    @Query('status') status?: LeaveStatus,
  ) {
    return this.leave.listAll(user, status);
  }

  @Patch('requests/:id/review')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  review(
    @CurrentUser() user: JwtPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReviewLeaveDto,
  ) {
    return this.leave.review(user, id, dto);
  }

  @Get('quota/:userId')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  getQuota(
    @CurrentUser() user: JwtPayload,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Query('year') year?: string,
  ) {
    return this.leave.getQuota(
      user,
      userId,
      year ? Number(year) : undefined,
    );
  }

  @Put('quota/:userId')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  setQuota(
    @CurrentUser() user: JwtPayload,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() dto: UpsertLeaveQuotaDto,
  ) {
    return this.leave.upsertQuota(user, userId, dto);
  }

  @Post('holidays')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  addHoliday(@CurrentUser() user: JwtPayload, @Body() dto: UpsertHolidayDto) {
    return this.leave.upsertHoliday(user, dto);
  }

  @Delete('holidays/:id')
  @Roles(AppRole.HR_ADMIN, AppRole.SUPER_ADMIN)
  removeHoliday(@Param('id', ParseUUIDPipe) id: string) {
    return this.leave.deleteHoliday(id);
  }
}
