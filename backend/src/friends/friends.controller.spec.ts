import { FriendsController } from './friends.controller';
import { FriendsService } from './friends.service';
import type { ValidatedUser } from '../auth/interfaces/auth-user.interface';

describe('FriendsController', () => {
  const user = { userId: 1 } as ValidatedUser;
  let service: Record<keyof FriendsService, jest.Mock>;
  let controller: FriendsController;

  beforeEach(() => {
    service = {
      sendFriendRequest: jest.fn().mockResolvedValue('sent'),
      acceptFriendRequest: jest.fn().mockResolvedValue('accepted'),
      rejectFriendRequest: jest.fn().mockResolvedValue('rejected'),
      blockUser: jest.fn().mockResolvedValue('blocked'),
      getFriends: jest.fn().mockResolvedValue(['friends']),
      getPendingRequests: jest.fn().mockResolvedValue(['requests']),
    } as unknown as Record<keyof FriendsService, jest.Mock>;
    controller = new FriendsController(service as unknown as FriendsService);
  });

  // Chaque route doit agir au nom de l'utilisateur du JWT, jamais d'un id fourni par le client.
  it('sendRequest uses the authenticated user id', async () => {
    await expect(controller.sendRequest(user, 'bob')).resolves.toBe('sent');
    expect(service.sendFriendRequest).toHaveBeenCalledWith(1, 'bob');
  });

  it('acceptRequest uses the authenticated user id', async () => {
    await expect(controller.acceptRequest(user, 9)).resolves.toBe('accepted');
    expect(service.acceptFriendRequest).toHaveBeenCalledWith(1, 9);
  });

  it('rejectRequest uses the authenticated user id', async () => {
    await expect(controller.rejectRequest(user, 9)).resolves.toBe('rejected');
    expect(service.rejectFriendRequest).toHaveBeenCalledWith(1, 9);
  });

  it('blockUser uses the authenticated user id', async () => {
    await expect(controller.blockUser(user, 'bob')).resolves.toBe('blocked');
    expect(service.blockUser).toHaveBeenCalledWith(1, 'bob');
  });

  it('getFriends returns the friends of the authenticated user', async () => {
    await expect(controller.getFriends(user)).resolves.toEqual(['friends']);
    expect(service.getFriends).toHaveBeenCalledWith(1);
  });

  it('getPendingRequests returns the requests of the authenticated user', async () => {
    await expect(controller.getPendingRequests(user)).resolves.toEqual(['requests']);
    expect(service.getPendingRequests).toHaveBeenCalledWith(1);
  });
});
