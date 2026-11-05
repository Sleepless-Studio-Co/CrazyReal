import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import type { ValidatedUser } from '../auth/interfaces/auth-user.interface';

describe('UsersController', () => {
  const user = { userId: 1 } as ValidatedUser;
  let service: {
    searchByUsername: jest.Mock;
    findPublicProfile: jest.Mock;
    updatePrivacy: jest.Mock;
  };
  let controller: UsersController;

  beforeEach(() => {
    service = {
      searchByUsername: jest.fn().mockResolvedValue([{ id: 2 }]),
      findPublicProfile: jest.fn().mockResolvedValue({ id: 2 }),
      updatePrivacy: jest.fn().mockResolvedValue({ id: 1, isPrivate: true }),
    };
    controller = new UsersController(service as unknown as UsersService);
  });

  describe('search', () => {
    it.each([undefined, '', '   '])('should return [] without querying for %p', async (q) => {
      expect(await controller.search(q as string, user)).toEqual([]);
      expect(service.searchByUsername).not.toHaveBeenCalled();
    });

    it('should trim the query and pass the requester id', async () => {
      await expect(controller.search('  bob ', user)).resolves.toEqual([{ id: 2 }]);
      expect(service.searchByUsername).toHaveBeenCalledWith('bob', 1);
    });
  });

  it('findOne should ask for the profile as the authenticated user', async () => {
    await expect(controller.findOne(2, user)).resolves.toEqual({ id: 2 });
    expect(service.findPublicProfile).toHaveBeenCalledWith(2, 1);
  });

  it('updatePrivacy should only change the authenticated user', async () => {
    await expect(controller.updatePrivacy(user, { isPrivate: true })).resolves.toEqual({
      user: { id: 1, isPrivate: true },
    });
    expect(service.updatePrivacy).toHaveBeenCalledWith(1, true);
  });
});
