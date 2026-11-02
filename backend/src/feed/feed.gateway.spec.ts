import { FeedGateway } from './feed.gateway';

describe('FeedGateway', () => {
  it('broadcasts a new post on the /feed namespace', () => {
    const gateway = new FeedGateway();
    const emit = jest.fn();
    gateway.server = { emit } as any;

    const post = { id: 1, photoUrl: '/uploads/a.jpg' };
    gateway.broadcastNewPost(post);

    expect(emit).toHaveBeenCalledWith('newPost', post);
  });
});
