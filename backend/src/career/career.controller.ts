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
import { CareerService } from './career.service';
import { CreateCareerPostDto } from './dto/create-career-post.dto';
import { UpdateCareerPostDto } from './dto/update-career-post.dto';
import { CareerFeedQueryDto } from './dto/feed.dto';
import { SendCareerMessageDto } from './dto/send-message.dto';

@ApiTags('Career')
@Controller({ path: 'career', version: '1' })
export class CareerController {
  constructor(private readonly service: CareerService) {}

  // ====== Feed (authentifié) ======
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('feed')
  async feed(@Query() q: CareerFeedQueryDto, @Req() req: any) {
    return this.service.feed(req.user, q);
  }

  // ====== Get single post ======
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('posts/:id')
  async getPost(@Param('id') id: string, @Req() req: any) {
    return this.service.getPublic(id, req.user);
  }

  // ====== Create post ======
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('posts')
  async create(@Req() req: any, @Body() dto: CreateCareerPostDto) {
    return this.service.create(req.user, dto);
  }

  // ====== Update post ======
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Patch('posts/:id')
  async update(@Req() req: any, @Param('id') id: string, @Body() dto: UpdateCareerPostDto) {
    return this.service.update(req.user, id, dto);
  }

  // ====== Delete post ======
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Delete('posts/:id')
  async remove(@Req() req: any, @Param('id') id: string) {
    return this.service.remove(req.user, id);
  }

  // ====== My posts ======
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('my/posts')
  async myPosts(@Req() req: any, @Query('type') type?: string) {
    return this.service.myPost(req.user, type as any);
  }

  // ====== Conversations ======
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('my/conversations')
  async myConversations(@Req() req: any) {
    return this.service.myConversations(req.user);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('posts/:id/contact')
  async contactPost(@Req() req: any, @Param('id') postId: string) {
    return this.service.contactPost(req.user, postId);
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
  async sendMessage(@Req() req: any, @Param('id') id: string, @Body() dto: SendCareerMessageDto) {
    return this.service.sendMessage(req.user, id, dto.content);
  }

  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Post('conversations/:id/hide')
  async hideConversation(@Req() req: any, @Param('id') id: string) {
    return this.service.hideConversation(req.user, id);
  }
}
