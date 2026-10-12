import {
  Controller,
  Post,
  Delete,
  Param,
  UseGuards,
  ParseIntPipe,
  Body,
  BadRequestException,
  Query,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { UpVotesService } from './upvotes.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { ValidatedUser } from '../auth/interfaces/auth-user.interface';

@ApiTags('Posts')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('posts')
export class UpVotesController {
  constructor(private readonly upVotesService: UpVotesService) {}

  @Post(':id/upvote')
  @ApiOperation({ summary: 'Voter pour un post' })
  @ApiResponse({ status: 201, description: 'Vote enregistré' })
  upvote(
    @CurrentUser() user: ValidatedUser,
    @Param('id', ParseIntPipe) postId: number,
  ) {
    return this.upVotesService.upvote(user.userId, postId);
  }

  @Delete(':id/upvote')
  @ApiOperation({ summary: 'Retirer son vote sur un post' })
  @ApiResponse({ status: 200, description: 'Vote retiré' })
  removeUpvote(
    @CurrentUser() user: ValidatedUser,
    @Param('id', ParseIntPipe) postId: number,
  ) {
    return this.upVotesService.removeUpvote(user.userId, postId);
  }

  @Post(':id/reaction')
  @ApiOperation({ summary: 'Ajouter une réaction emoji à un post' })
  addReaction(
    @CurrentUser() user: ValidatedUser,
    @Param('id', ParseIntPipe) postId: number,
    @Body('emoji') emoji: string,
  ) {
    if (!emoji || emoji.length > 255) {
      throw new BadRequestException('Emoji invalide.');
    }
    return this.upVotesService.addReaction(user.userId, postId, emoji);
  }

  @Delete(':id/reaction')
  @ApiOperation({ summary: 'Retirer une réaction emoji d’un post' })
  removeReaction(
    @CurrentUser() user: ValidatedUser,
    @Param('id', ParseIntPipe) postId: number,
    @Query('emoji') emoji: string,
  ) {
    if (!emoji || emoji.length > 255) {
      throw new BadRequestException('Emoji invalide.');
    }
    return this.upVotesService.removeReaction(user.userId, postId, emoji);
  }
}
