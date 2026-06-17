import { Controller, Post, Patch, Body, UseGuards, Param, ParseIntPipe, Get, Query, Delete } from '@nestjs/common';
import { ChatService } from './chat.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { ValidatedUser } from '../auth/interfaces/auth-user.interface';
import { ChatGateway } from './chat.gateway';
import { CreateChatDto } from './dto/create-chat.dto';
import { CreateMessageDto } from './dto/create-message.dto';
import { GetMessagesQueryDto } from './dto/get-messages-query.dto';
import { GetConversationsQueryDto } from './dto/get-conversations-query.dto';

@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(
    private readonly chatService: ChatService,
    private readonly chatGateway: ChatGateway,
  ) {}

  @Post('group')
  createGroup(@CurrentUser() user: ValidatedUser, @Body() createGroupDto: CreateChatDto) {
    return this.chatService.createGroup(
      user.userId,
      createGroupDto.name,
      createGroupDto.members,
    );
  }

  @Get()
  getConversations(
    @CurrentUser() user: ValidatedUser,
    @Query() query: GetConversationsQueryDto,
  ) {
    return this.chatService.getConversations(user.userId, query.page, query.limit);
  }

  @Get(':id/members')
  getMembers(
    @Param('id', ParseIntPipe) conversationId: number,
    @CurrentUser() user: ValidatedUser,
  ) {
    return this.chatService.getMembers(conversationId, user.userId);
  }

  @Delete(':id/leave')
  leaveGroup(
    @Param('id', ParseIntPipe) conversationId: number,
    @CurrentUser() user: ValidatedUser,
  ) {
    return this.chatService.leaveGroup(conversationId, user.userId);
  }

  @Delete(':id/members/:memberId')
  removeMember(
    @Param('id', ParseIntPipe) conversationId: number,
    @Param('memberId', ParseIntPipe) memberId: number,
    @CurrentUser() user: ValidatedUser,
  ) {
    return this.chatService.removeMember(conversationId, user.userId, memberId);
  }

  @Patch(':id/members/:memberId/promote')
  promoteMember(
    @Param('id', ParseIntPipe) conversationId: number,
    @Param('memberId', ParseIntPipe) memberId: number,
    @CurrentUser() user: ValidatedUser,
  ) {
    return this.chatService.promoteMember(conversationId, user.userId, memberId);
  }

  @Patch(':id/members/:memberId/demote')
  demoteMember(
    @Param('id', ParseIntPipe) conversationId: number,
    @Param('memberId', ParseIntPipe) memberId: number,
    @CurrentUser() user: ValidatedUser,
  ) {
    return this.chatService.demoteMember(conversationId, user.userId, memberId);
  }

  @Post(':id/messages')
  async sendMessage(
    @Param('id', ParseIntPipe) conversationId: number,
    @CurrentUser() user: ValidatedUser,
    @Body() body: CreateMessageDto,
  ) {
    const message = await this.chatService.sendMessage(conversationId, user.userId, body.content);
    this.chatGateway.broadcastNewMessage(conversationId, message);
    return message;
  }

  @Get(':id/messages')
  getMessages(
    @Param('id', ParseIntPipe) conversationId: number,
    @CurrentUser() user: ValidatedUser,
    @Query() query: GetMessagesQueryDto,
  ) {
    return this.chatService.getMessages(conversationId, user.userId, query.limit, query.cursor, query.after);
  }
}
