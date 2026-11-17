import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { UpVotesController } from './upvotes.controller';
import { UpVotesService } from './upvotes.service';

describe('UpVotesController', () => {
  let controller: UpVotesController;
  let upVotesService: {
    upvote: jest.Mock;
    removeUpvote: jest.Mock;
    addReaction: jest.Mock;
    removeReaction: jest.Mock;
  };

  const user = { userId: 1, email: 'a@b.com', username: 'alice' };

  beforeEach(async () => {
    upVotesService = {
      upvote: jest.fn(),
      removeUpvote: jest.fn(),
      addReaction: jest.fn(),
      removeReaction: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [UpVotesController],
      providers: [{ provide: UpVotesService, useValue: upVotesService }],
    }).compile();

    controller = module.get<UpVotesController>(UpVotesController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('delegates upvote to the service', async () => {
    upVotesService.upvote.mockResolvedValue({ id: 1 });
    await expect(controller.upvote(user, 1)).resolves.toEqual({ id: 1 });
    expect(upVotesService.upvote).toHaveBeenCalledWith(1, 1);
  });

  it('delegates removeUpvote to the service', async () => {
    upVotesService.removeUpvote.mockResolvedValue({ id: 1 });
    await expect(controller.removeUpvote(user, 1)).resolves.toEqual({ id: 1 });
    expect(upVotesService.removeUpvote).toHaveBeenCalledWith(1, 1);
  });

  describe('addReaction', () => {
    it('rejects an empty emoji', () => {
      expect(() => controller.addReaction(user, 1, '')).toThrow(
        BadRequestException,
      );
      expect(upVotesService.addReaction).not.toHaveBeenCalled();
    });

    it('delegates a valid emoji to the service', async () => {
      upVotesService.addReaction.mockResolvedValue({ id: 1 });
      await controller.addReaction(user, 1, '🔥');
      expect(upVotesService.addReaction).toHaveBeenCalledWith(1, 1, '🔥');
    });
  });

  describe('removeReaction', () => {
    it('rejects an empty emoji', () => {
      expect(() => controller.removeReaction(user, 1, '')).toThrow(
        BadRequestException,
      );
    });

    it('delegates a valid emoji to the service', async () => {
      upVotesService.removeReaction.mockResolvedValue({ id: 1 });
      await controller.removeReaction(user, 1, '🔥');
      expect(upVotesService.removeReaction).toHaveBeenCalledWith(1, 1, '🔥');
    });
  });
});
