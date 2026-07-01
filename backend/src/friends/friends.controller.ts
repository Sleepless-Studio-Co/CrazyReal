import { Controller, Post, Patch, Get, Param, UseGuards, ParseIntPipe } from '@nestjs/common';
import { FriendsService } from './friends.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { ValidatedUser } from '../auth/interfaces/auth-user.interface';

@UseGuards(JwtAuthGuard)
@Controller('friends')
export class FriendsController {
  constructor(private readonly friendsService: FriendsService) {}

  @Post('request/:username')
  sendRequest(
    @CurrentUser() user: ValidatedUser,
    @Param('username') username: string,
  ) {
    return this.friendsService.sendFriendRequest(user.userId, username);
  }

  @Patch('accept/:requestId')
  acceptRequest(
    @CurrentUser() user: ValidatedUser,
    @Param('requestId', ParseIntPipe) requestId: number,
  ) {
    return this.friendsService.acceptFriendRequest(user.userId, requestId);
  }

  @Patch('reject/:requestId')
  rejectRequest(
    @CurrentUser() user: ValidatedUser,
    @Param('requestId', ParseIntPipe) requestId: number,
  ) {
    return this.friendsService.rejectFriendRequest(user.userId, requestId);
  }

  @Post('block/:username')
  blockUser(
    @CurrentUser() user: ValidatedUser,
    @Param('username') username: string,
  ) {
    return this.friendsService.blockUser(user.userId, username);
  }

  @Get()
  getFriends(@CurrentUser() user: ValidatedUser) {
    return this.friendsService.getFriends(user.userId);
  }

  @Get('requests')
  getPendingRequests(@CurrentUser() user: ValidatedUser) {
    return this.friendsService.getPendingRequests(user.userId);
  }
}