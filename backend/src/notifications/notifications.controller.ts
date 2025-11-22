import { Controller, Delete, Get, Param, Patch, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { NotificationsService } from './notifications.service';

@ApiTags('Notifications')
@Controller({ path: 'notifications', version: '1' })
export class NotificationsController {
  constructor(private readonly service: NotificationsService) {}

  // Récupérer toutes les notifications de l'utilisateur connecté
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get()
  async getMyNotifications(@Req() req: any) {
    const userId = req.user.id ?? req.user.sub;
    return this.service.getUserNotifications(userId);
  }

  // Récupérer le nombre de notifications non lues
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('unread/count')
  async getUnreadCount(@Req() req: any) {
    const userId = req.user.id ?? req.user.sub;
    const count = await this.service.getUnreadCount(userId);
    return { count };
  }

  // Marquer une notification comme lue
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Patch(':id/read')
  async markAsRead(@Req() req: any, @Param('id') id: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.service.markAsRead(id, userId);
  }

  // Marquer toutes les notifications comme lues
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Patch('read-all')
  async markAllAsRead(@Req() req: any) {
    const userId = req.user.id ?? req.user.sub;
    return this.service.markAllAsRead(userId);
  }

  // Supprimer une notification
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Delete(':id')
  async deleteNotification(@Req() req: any, @Param('id') id: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.service.deleteNotification(id, userId);
  }

  // Supprimer toutes les notifications
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Delete()
  async deleteAllNotifications(@Req() req: any) {
    const userId = req.user.id ?? req.user.sub;
    return this.service.deleteAllNotifications(userId);
  }
}
