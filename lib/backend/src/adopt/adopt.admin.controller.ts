// src/adopt/adopt.admin.controller.ts
import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Query,
  UseGuards,
  Injectable,
  CanActivate,
  ExecutionContext,
  ParseEnumPipe,
  ParseIntPipe,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AdoptService } from './adopt.service';
import { AuthGuard } from '@nestjs/passport';
import { AdoptStatus } from '@prisma/client';
import { RejectPostDto } from './dto/reject-post.dto';

@Injectable()
class AdminOnlyGuard implements CanActivate {
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    const role = req?.user?.role;
    return role === 'ADMIN' || role === 'admin';
  }
}

@ApiTags('AdoptAdmin')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'), AdminOnlyGuard)
@Controller({ path: 'admin/adopt', version: '1' })
export class AdoptAdminController {
  constructor(private readonly service: AdoptService) {}

  @Get('posts')
  async list(
    @Query('status', new ParseEnumPipe(AdoptStatus, { optional: true })) status?: AdoptStatus,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
    @Query('cursor') cursor?: string,
  ) {
    return this.service.adminList(status, limit ?? 30, cursor);
  }

  @Patch('posts/:id/approve')
  async approve(@Req() req: any, @Param('id') id: string) {
    return this.service.adminApprove(req.user, id);
  }

  @Patch('posts/:id/reject')
  async reject(@Req() req: any, @Param('id') id: string, @Body() dto: RejectPostDto) {
    const note = dto.reasons?.length
      ? `Raisons: ${dto.reasons.join(', ')}${dto.note ? ` | Note: ${dto.note}` : ''}`
      : dto.note;
    return this.service.adminReject(req.user, id, note);
  }

  @Patch('posts/:id/archive')
  async archive(@Req() req: any, @Param('id') id: string) {
    return this.service.adminArchive(req.user, id);
  }

  @Patch('posts/approve-all')
  async approveAll(@Req() req: any) {
    return this.service.adminApproveAll(req.user);
  }

  @Get('conversations')
  async getAllConversations(
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.service.adminGetAllConversations(limit ?? 50);
  }

  @Get('conversations/:id')
  async getConversationDetails(@Param('id') id: string) {
    return this.service.adminGetConversationDetails(id);
  }
}
