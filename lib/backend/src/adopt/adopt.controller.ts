import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { AdoptService } from './adopt.service';
import { CreateAdoptPostDto } from './dto/create-adopt-post.dto';
import { UpdateAdoptPostDto } from './dto/update-adopt-post.dto';
import { FeedQueryDto } from './dto/feed.dto';
import { SwipeDto } from './dto/swipe.dto';
import { SendMessageDto } from './dto/send-message.dto';

@ApiTags('Adopt')
@Controller({ path: 'adopt', version: '1' })
export class AdoptController {
  constructor(private readonly service: AdoptService) {}

  // ====== Feed public ======
  @Get('feed')
  async feed(@Query() q: FeedQueryDto, @Req() req: any) {
    const user = req.user ?? null;
    return this.service.feed(user, q);
  }

  @Get('posts/:id')
  async getPost(@Param('id') id: string) {
    return this.service.getPublic(id);
  }

  // ====== Posts (authentifié) ======
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('posts')
  async create(@Req() req: any, @Body() dto: CreateAdoptPostDto) {
    return this.service.create(req.user, dto);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Patch('posts/:id')
  async update(@Req() req: any, @Param('id') id: string, @Body() dto: UpdateAdoptPostDto) {
    return this.service.update(req.user, id, dto);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Delete('posts/:id')
  async remove(@Req() req: any, @Param('id') id: string) {
    return this.service.remove(req.user, id);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('my/posts')
  async myPosts(@Req() req: any) {
    return this.service.listMine(req.user);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('posts/:id/conversations')
  async getPostConversations(@Req() req: any, @Param('id') id: string) {
    return this.service.getPostConversations(req.user, id);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('posts/:id/adopted')
  async markAdopted(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { adoptedById?: string },
  ) {
    return this.service.markAsAdopted(req.user, id, body.adoptedById);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('my/pending-pet-creation')
  async myPendingPetCreation(@Req() req: any) {
    return this.service.myPendingPetCreation(req.user);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('posts/:id/mark-pet-created')
  async markPetProfileCreated(@Req() req: any, @Param('id') id: string) {
    return this.service.markPetProfileCreated(req.user, id);
  }

  // ====== Swipe ======
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('posts/:id/swipe')
  async swipe(@Req() req: any, @Param('id') id: string, @Body() dto: SwipeDto) {
    return this.service.swipe(req.user, id, dto);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('my/likes')
  async myLikes(@Req() req: any) {
    return this.service.myLikes(req.user);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('my/quotas')
  async myQuotas(@Req() req: any) {
    const userId = req.user.id ?? req.user.sub;
    return this.service.getQuotas(userId);
  }

  // ====== Requests (demandes d'adoption) ======
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('my/requests/incoming')
  async incomingRequests(@Req() req: any) {
    return this.service.myIncomingRequests(req.user);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('my/requests/outgoing')
  async outgoingRequests(@Req() req: any) {
    return this.service.myOutgoingRequests(req.user);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('requests/:id/accept')
  async acceptRequest(@Req() req: any, @Param('id') id: string) {
    return this.service.acceptRequest(req.user, id);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('requests/:id/reject')
  async rejectRequest(@Req() req: any, @Param('id') id: string) {
    return this.service.rejectRequest(req.user, id);
  }

  // ====== Conversations & Messages ======
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('my/conversations')
  async myConversations(@Req() req: any) {
    return this.service.myConversations(req.user);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('conversations/:id/messages')
  async getMessages(@Req() req: any, @Param('id') id: string) {
    return this.service.getConversationMessages(req.user, id);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('conversations/:id/messages')
  async sendMessage(@Req() req: any, @Param('id') id: string, @Body() dto: SendMessageDto) {
    return this.service.sendMessage(req.user, id, dto.content);
  }

  // ====== Adoption Confirmation ======
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('conversations/:id/confirm-adoption')
  async confirmAdoption(@Req() req: any, @Param('id') conversationId: string) {
    return this.service.confirmAdoption(req.user, conversationId);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('conversations/:id/decline-adoption')
  async declineAdoption(@Req() req: any, @Param('id') conversationId: string) {
    return this.service.declineAdoption(req.user, conversationId);
  }

  // ====== Hide Conversation (Soft Delete) ======
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('conversations/:id/hide')
  async hideConversation(@Req() req: any, @Param('id') conversationId: string) {
    return this.service.hideConversation(req.user, conversationId);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('conversations/:id/report')
  async reportConversation(
    @Req() req: any,
    @Param('id') conversationId: string,
    @Body('reason') reason: string,
  ) {
    return this.service.reportConversation(req.user, conversationId, reason);
  }
}
