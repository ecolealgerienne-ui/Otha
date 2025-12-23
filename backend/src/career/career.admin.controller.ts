import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Query,
  Req,
  UseGuards,
  Injectable,
  CanActivate,
  ExecutionContext,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { CareerService } from './career.service';
import { RejectCareerPostDto } from './dto/reject-post.dto';
import { CareerStatus, CareerType } from '@prisma/client';

@Injectable()
class AdminOnlyGuard implements CanActivate {
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    const role = req?.user?.role;
    return role === 'ADMIN' || role === 'admin';
  }
}

@ApiTags('CareerAdmin')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'), AdminOnlyGuard)
@Controller({ path: 'admin/career', version: '1' })
export class CareerAdminController {
  constructor(private readonly service: CareerService) {}

  @Get('posts')
  async list(
    @Query('status') status?: CareerStatus,
    @Query('type') type?: CareerType,
    @Query('limit') limit?: number,
    @Query('cursor') cursor?: string,
  ) {
    return this.service.adminList(status, type, limit ? +limit : undefined, cursor);
  }

  @Patch('posts/:id/approve')
  async approve(@Req() req: any, @Param('id') id: string) {
    return this.service.adminApprove(req.user, id);
  }

  @Patch('posts/:id/reject')
  async reject(@Req() req: any, @Param('id') id: string, @Body() dto: RejectCareerPostDto) {
    const note = dto.reasons?.length
      ? `${dto.reasons.join(', ')}${dto.note ? ` - ${dto.note}` : ''}`
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

  @Get('posts/:id')
  async getPost(@Param('id') id: string) {
    return this.service.adminGetPost(id);
  }

  @Get('posts/:id/conversations')
  async getPostConversations(@Param('id') id: string) {
    return this.service.adminGetPostConversations(id);
  }

  @Get('conversations/:id/messages')
  async getConversationMessages(@Param('id') id: string) {
    return this.service.adminGetConversationMessages(id);
  }
}
