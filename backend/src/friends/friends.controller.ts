import { Controller, Post, Patch, Get, Param, UseGuards, ParseIntPipe } from '@nestjs/common';
import { FriendsService } from './friends.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { ValidatedUser } from '../auth/interfaces/auth-user.interface';

@UseGuards(JwtAuthGuard)
@Controller('friends')
export class FriendsController {
  constructor(private readonly friendsService: FriendsService) {}

  // Route pour envoyer une demande d'ami
  @Post('request/:username')
  sendRequest(
    @CurrentUser() user: ValidatedUser,
    @Param('username') username: string,
  ) {
    return this.friendsService.sendFriendRequest(user.userId, username);
  }

  // Route pour accepter une demande
  @Patch('accept/:requestId')
  acceptRequest(
    @CurrentUser() user: ValidatedUser,
    @Param('requestId', ParseIntPipe) requestId: number,
  ) {
    // C'était ici le problème : on remplace user.id par user.userId
    return this.friendsService.acceptFriendRequest(user.userId, requestId);
  }

  // Route pour lister ses amis
  @Get()
  getFriends(@CurrentUser() user: ValidatedUser) {
    // Ici aussi, on sécurise avec user.userId
    return this.friendsService.getFriends(user.userId);
  }

  // Route pour lister ses demandes en attente
  @Get('requests')
  getPendingRequests(@CurrentUser() user: ValidatedUser) {
    return this.friendsService.getPendingRequests(user.userId);
  }
}