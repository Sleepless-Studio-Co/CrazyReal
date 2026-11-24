import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/feed_post.dart';

void main() {
  group('parsePostMediaType', () {
    test('parses VIDEO (case-insensitive)', () {
      expect(parsePostMediaType('VIDEO'), PostMediaType.video);
      expect(parsePostMediaType('video'), PostMediaType.video);
    });

    test('defaults to photo for anything else', () {
      expect(parsePostMediaType('PHOTO'), PostMediaType.photo);
      expect(parsePostMediaType(null), PostMediaType.photo);
      expect(parsePostMediaType('gif'), PostMediaType.photo);
    });
  });

  group('FeedUser.fromJson', () {
    test('parses a full user', () {
      final user = FeedUser.fromJson({
        'id': 1,
        'username': 'alice',
        'avatarUrl': '/uploads/a.png',
        'avatarKey': 'ember',
      });
      expect(user.id, 1);
      expect(user.username, 'alice');
      expect(user.avatarUrl, '/uploads/a.png');
      expect(user.avatarKey, 'ember');
    });

    test('handles missing fields', () {
      final user = FeedUser.fromJson({'id': 2});
      expect(user.username, '');
      expect(user.avatarUrl, isNull);
      expect(user.avatarKey, isNull);
    });
  });

  group('FeedPost.fromJson', () {
    test('parses a post with reactions and video media type', () {
      final post = FeedPost.fromJson({
        'id': 10,
        'photoUrl': '/uploads/v.mp4',
        'createdAt': '2026-01-01T12:00:00.000Z',
        'mediaType': 'VIDEO',
        'upvoteCount': 3,
        'hasUpvoted': true,
        'user': {'id': 1, 'username': 'alice'},
        'challenge': {'id': 5, 'title': 'Défi', 'type': 'WEEKLY_A'},
        'reactions': [
          {'emoji': '🔥', 'count': 2, 'reactedByMe': true},
        ],
      });

      expect(post.id, 10);
      expect(post.isVideo, isTrue);
      expect(post.createdAt, DateTime.parse('2026-01-01T12:00:00.000Z'));
      expect(post.upvoteCount, 3);
      expect(post.hasUpvoted, isTrue);
      expect(post.user.username, 'alice');
      expect(post.challenge?.title, 'Défi');
      expect(post.reactions.single.emoji, '🔥');
    });

    test('applies defaults when optional fields are absent', () {
      final post = FeedPost.fromJson({
        'id': 1,
        'photoUrl': '/uploads/x.jpg',
        'user': {'id': 2, 'username': 'bob'},
      });

      expect(post.upvoteCount, 0);
      expect(post.hasUpvoted, isFalse);
      expect(post.isVideo, isFalse);
      expect(post.challenge, isNull);
      expect(post.reactions, isEmpty);
      expect(post.createdAt, isNull);
    });
  });

  group('FeedPost.listFromJson', () {
    test('returns an empty list for non-list input', () {
      expect(FeedPost.listFromJson(null), isEmpty);
      expect(FeedPost.listFromJson('nope'), isEmpty);
    });

    test('maps a list of posts', () {
      final posts = FeedPost.listFromJson([
        {'id': 1, 'photoUrl': '/a.jpg', 'user': {'id': 1, 'username': 'a'}},
        {'id': 2, 'photoUrl': '/b.jpg', 'user': {'id': 2, 'username': 'b'}},
      ]);
      expect(posts.map((p) => p.id), [1, 2]);
    });
  });

  group('FeedPost.copyWith', () {
    test('updates the vote state and preserves the rest', () {
      final post = FeedPost(
        id: 1,
        photoUrl: '/a.jpg',
        user: const FeedUser(id: 1, username: 'a'),
        upvoteCount: 2,
        hasUpvoted: false,
      );

      final updated = post.copyWith(upvoteCount: 3, hasUpvoted: true);

      expect(updated.id, 1);
      expect(updated.upvoteCount, 3);
      expect(updated.hasUpvoted, isTrue);
      expect(updated.photoUrl, '/a.jpg');
    });
  });

  group('FeedPost.sameVoteState', () {
    FeedPost post(int id, {int upvoteCount = 0, bool hasUpvoted = false, List<FeedReaction> reactions = const []}) {
      return FeedPost(
        id: id,
        photoUrl: '/a.jpg',
        user: const FeedUser(id: 1, username: 'a'),
        upvoteCount: upvoteCount,
        hasUpvoted: hasUpvoted,
        reactions: reactions,
      );
    }

    test('returns true for identical vote state', () {
      expect(FeedPost.sameVoteState([post(1)], [post(1)]), isTrue);
    });

    test('returns false when lists differ in length', () {
      expect(FeedPost.sameVoteState([post(1)], []), isFalse);
    });

    test('returns false when the upvote count differs', () {
      expect(
        FeedPost.sameVoteState(
          [post(1, upvoteCount: 1)],
          [post(1, upvoteCount: 2)],
        ),
        isFalse,
      );
    });

    test('returns false when reactions differ', () {
      expect(
        FeedPost.sameVoteState(
          [post(1, reactions: const [FeedReaction(emoji: '🔥', count: 1, reactedByMe: false)])],
          [post(1)],
        ),
        isFalse,
      );
    });
  });

  group('AvailableChallenge', () {
    test('marks a challenge with no group as global', () {
      final challenge = AvailableChallenge.fromJson({'id': 1, 'title': 'Défi'});
      expect(challenge.isGlobal, isTrue);
      expect(challenge.groupName, isNull);
    });

    test('extracts the group name for group challenges', () {
      final challenge = AvailableChallenge.fromJson({
        'id': 1,
        'title': 'Défi',
        'group': {'id': 3, 'name': 'Les potes'},
      });
      expect(challenge.isGlobal, isFalse);
      expect(challenge.groupName, 'Les potes');
    });

    test('label combines scope, group and title', () {
      final challenge = AvailableChallenge.fromJson({
        'id': 1,
        'title': 'Défi',
        'group': {'id': 3, 'name': 'Les potes'},
      });
      expect(challenge.label('Global', 'Friends'), 'Friends · Les potes · Défi');
    });
  });
}
