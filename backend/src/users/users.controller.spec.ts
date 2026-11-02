import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

describe('UsersController', () => {
  let controller: UsersController;
  let usersService: {
    searchByUsername: jest.Mock;
    findPublicProfile: jest.Mock;
    deleteAccount: jest.Mock;
    updatePrivacy: jest.Mock;
    updateAvatar: jest.Mock;
  };

  const user = { userId: 1, email: 'a@b.com', username: 'alice' };

  beforeEach(async () => {
    usersService = {
      searchByUsername: jest.fn(),
      findPublicProfile: jest.fn(),
      deleteAccount: jest.fn(),
      updatePrivacy: jest.fn(),
      updateAvatar: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [{ provide: UsersService, useValue: usersService }],
    }).compile();

    controller = module.get<UsersController>(UsersController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('search', () => {
    it('returns an empty list for a blank query without hitting the service', () => {
      expect(controller.search('   ', user)).toEqual([]);
      expect(usersService.searchByUsername).not.toHaveBeenCalled();
    });

    it('delegates a non-empty query to the service', async () => {
      usersService.searchByUsername.mockResolvedValue([{ id: 2 }]);
      await expect(controller.search('bob', user)).resolves.toEqual([
        { id: 2 },
      ]);
      expect(usersService.searchByUsername).toHaveBeenCalledWith('bob', 1);
    });
  });

  describe('findOne', () => {
    it('delegates to findPublicProfile', async () => {
      usersService.findPublicProfile.mockResolvedValue({ id: 2 });
      await controller.findOne(2, user);
      expect(usersService.findPublicProfile).toHaveBeenCalledWith(2, 1);
    });
  });

  describe('deleteAccount', () => {
    it('deletes the account and returns a confirmation message', async () => {
      usersService.deleteAccount.mockResolvedValue(undefined);
      await expect(controller.deleteAccount(user)).resolves.toEqual({
        message: 'Account deleted',
      });
      expect(usersService.deleteAccount).toHaveBeenCalledWith(1);
    });
  });

  describe('updatePrivacy', () => {
    it('updates the privacy flag and returns the updated user', async () => {
      usersService.updatePrivacy.mockResolvedValue({ id: 1, isPrivate: true });
      await expect(
        controller.updatePrivacy(user, { isPrivate: true }),
      ).resolves.toEqual({ user: { id: 1, isPrivate: true } });
      expect(usersService.updatePrivacy).toHaveBeenCalledWith(1, true);
    });
  });

  describe('updateAvatarKey', () => {
    it('clears the uploaded avatar and stores the new base key', async () => {
      usersService.updateAvatar.mockResolvedValue({
        id: 1,
        avatarKey: 'ember',
      });
      await expect(
        controller.updateAvatarKey(user, { avatarKey: 'ember' }),
      ).resolves.toEqual({ user: { id: 1, avatarKey: 'ember' } });
      expect(usersService.updateAvatar).toHaveBeenCalledWith(1, {
        avatarKey: 'ember',
        avatarUrl: null,
      });
    });
  });

  describe('uploadAvatar', () => {
    it('throws BadRequestException when no file is provided', async () => {
      await expect(
        controller.uploadAvatar(undefined as any, user),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(usersService.updateAvatar).not.toHaveBeenCalled();
    });

    it('stores the uploaded avatar url', async () => {
      const file = { filename: 'avatar-123.png' } as Express.Multer.File;
      usersService.updateAvatar.mockResolvedValue({ id: 1 });

      await expect(controller.uploadAvatar(file, user)).resolves.toEqual({
        user: { id: 1 },
      });
      expect(usersService.updateAvatar).toHaveBeenCalledWith(1, {
        avatarUrl: '/uploads/avatar-123.png',
        avatarKey: null,
      });
    });
  });

  describe('clearAvatar', () => {
    it('removes avatar information', async () => {
      usersService.updateAvatar.mockResolvedValue({ id: 1 });
      await controller.clearAvatar(user);
      expect(usersService.updateAvatar).toHaveBeenCalledWith(1, {
        avatarUrl: null,
        avatarKey: null,
      });
    });
  });
});
