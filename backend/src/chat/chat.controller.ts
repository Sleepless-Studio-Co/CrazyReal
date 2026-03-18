import { Controller, Post, Body, UseGuards, Param, ParseIntPipe, Get } from '@nestjs/common';
import { ChatService } from './chat.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { ValidatedUser } from '../auth/interfaces/auth-user.interface';
import { ChatGateway } from './chat.gateway';

@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(
    private readonly chatService: ChatService,
    private readonly chatGateway: ChatGateway,
  ) {}

  @Post('group')
  createGroup(
    @CurrentUser() user: ValidatedUser,
    @Body() createGroupDto: { name: string; members: number[] },
  ) {
    return this.chatService.createGroup(
      user.userId,
      createGroupDto.name,
      createGroupDto.members,
    );
  }

  @Get()
  getConversations(@CurrentUser() user: ValidatedUser) {
    return this.chatService.getConversations(user.userId);
  }

  @Post(':id/messages')
  async sendMessage(
    @Param('id', ParseIntPipe) conversationId: number,
    @CurrentUser() user: ValidatedUser,
    @Body('content') content: string,
  ) {
    const message = await this.chatService.sendMessage(conversationId, user.userId, content);
    this.chatGateway.broadcastNewMessage(conversationId, message);
    return message;
  }

  @Get(':id/messages')
  getMessages(
    @Param('id', ParseIntPipe) conversationId: number,
    @CurrentUser() user: ValidatedUser,
  ) {
    return this.chatService.getMessages(conversationId, user.userId);
  }
}