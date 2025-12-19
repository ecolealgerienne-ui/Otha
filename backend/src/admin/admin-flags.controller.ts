import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
  Injectable,
  CanActivate,
  ExecutionContext,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { AdminFlagsService, FlagWithUser } from './admin-flags.service';

@Injectable()
class AdminOnlyGuard implements CanActivate {
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    const role = req?.user?.role;
    return role === 'ADMIN' || role === 'admin';
  }
}

@ApiTags('AdminFlags')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'), AdminOnlyGuard)
@Controller({ path: 'admin/flags', version: '1' })
export class AdminFlagsController {
  constructor(private readonly service: AdminFlagsService) {}

  // GET /admin/flags - List all flags
  @Get()
  async list(
    @Query('resolved') resolved?: string,
    @Query('type') type?: string,
    @Query('userId') userId?: string,
    @Query('limit') limit?: string,
  ): Promise<FlagWithUser[]> {
    return this.service.list({
      resolved: resolved === 'true' ? true : resolved === 'false' ? false : undefined,
      type,
      userId,
      limit: limit ? parseInt(limit, 10) : 50,
    });
  }

  // GET /admin/flags/stats - Get stats
  @Get('stats')
  async getStats() {
    return this.service.getStats();
  }

  // GET /admin/flags/:id - Get single flag
  @Get(':id')
  async getById(@Param('id') id: string) {
    return this.service.getById(id);
  }

  // POST /admin/flags - Create a flag
  @Post()
  async create(
    @Body() dto: { userId: string; type: string; bookingId?: string; note?: string },
  ) {
    return this.service.create(dto);
  }

  // PATCH /admin/flags/:id/resolve - Resolve a flag
  @Patch(':id/resolve')
  async resolve(@Param('id') id: string, @Body() dto: { note?: string }) {
    return this.service.resolve(id, dto.note);
  }

  // PATCH /admin/flags/:id/unresolve - Unresolve a flag
  @Patch(':id/unresolve')
  async unresolve(@Param('id') id: string) {
    return this.service.unresolve(id);
  }

  // DELETE /admin/flags/:id - Delete a flag
  @Delete(':id')
  async delete(@Param('id') id: string) {
    return this.service.delete(id);
  }

  // GET /admin/flags/user/:userId - Get all flags for a user
  @Get('user/:userId')
  async getByUser(@Param('userId') userId: string) {
    return this.service.getByUser(userId);
  }
}
