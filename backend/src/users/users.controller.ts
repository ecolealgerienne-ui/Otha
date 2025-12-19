import { Body, Controller, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/guards/jwt.guard';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UpdateMeDto } from './dto/update-me.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'users', version: '1' })
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  async me(@Req() req: any) {
    return this.users.findMe(req.user.sub);
  }

  @Patch('me')
  async updateMe(@Req() req: any, @Body() dto: UpdateMeDto) {
    return this.users.updateMe(req.user.sub, dto);
  }

  // Admin endpoint
  @Roles('ADMIN')
  @UseGuards(RolesGuard)
  @Get('list')
  async listUsers(
    @Query('role') role?: string,
    @Query('q') q?: string,
    @Query('limit') limitStr?: string,
    @Query('offset') offsetStr?: string,
  ) {
    const limit = limitStr ? parseInt(limitStr, 10) : 100;
    const offset = offsetStr ? parseInt(offsetStr, 10) : 0;

    return this.users.listUsers({ role, q, limit, offset });
  }

  // Admin: reset quotas adoption d'un user
  @Roles('ADMIN')
  @UseGuards(RolesGuard)
  @Post(':id/reset-adopt-quotas')
  async resetUserAdoptQuotas(@Param('id') userId: string) {
    return this.users.resetUserAdoptQuotas(userId);
  }

  // Admin: get user quotas
  @Roles('ADMIN')
  @UseGuards(RolesGuard)
  @Get(':id/quotas')
  async getUserQuotas(@Param('id') userId: string) {
    return this.users.getUserQuotas(userId);
  }

  // Admin: get user adoption conversations
  @Roles('ADMIN')
  @UseGuards(RolesGuard)
  @Get(':id/adopt-conversations')
  async getUserAdoptConversations(@Param('id') userId: string) {
    return this.users.getUserAdoptConversations(userId);
  }

  // Admin: get user adoption posts (all statuses)
  @Roles('ADMIN')
  @UseGuards(RolesGuard)
  @Get(':id/adopt-posts')
  async getUserAdoptPosts(@Param('id') userId: string) {
    return this.users.getUserAdoptPosts(userId);
  }

  // Admin: reset user trust status (fix accidental penalties)
  @Roles('ADMIN')
  @UseGuards(RolesGuard)
  @Post(':id/reset-trust')
  async resetUserTrustStatus(@Param('id') userId: string) {
    return this.users.resetUserTrustStatus(userId);
  }

  // Admin: update user info
  @Roles('ADMIN')
  @UseGuards(RolesGuard)
  @Patch(':id')
  async adminUpdateUser(@Param('id') userId: string, @Body() dto: any) {
    return this.users.adminUpdateUser(userId, dto);
  }
}
