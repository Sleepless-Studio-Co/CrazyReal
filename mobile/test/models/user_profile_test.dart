import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/feed_post.dart';

import '../helpers.dart';

void main() {
  group('UserProfile.fromJson', () {
    test('parses a public profile with its posts', () {
      final profile = UserProfile.fromJson(profileJson(
        friendCount: 12,
        posts: [postJson(1, upvotes: 3, hasUpvoted: true), postJson(2)],
      ));

      expect(profile.user.id, 2);
      expect(profile.user.username, 'bob');
      expect(profile.friendCount, 12);
      expect(profile.posts.map((p) => p.id), [1, 2]);
      expect(profile.posts.first.upvoteCount, 3);
      expect(profile.posts.first.hasUpvoted, isTrue);
      expect(profile.isLocked, isFalse);
    });

    test('parses the minimal locked payload sent for private accounts', () {
      final profile = UserProfile.fromJson({
        'id': 2,
        'username': 'bob',
        'avatarUrl': null,
        'avatarKey': 'sea',
        'isPrivate': true,
        'isFriend': false,
        'isSelf': false,
        'friendCount': 4,
        'posts': <dynamic>[],
      });

      expect(profile.isLocked, isTrue);
      expect(profile.user.avatarKey, 'sea');
      expect(profile.posts, isEmpty);
    });

    test('survives missing or malformed optional fields', () {
      final profile = UserProfile.fromJson({'id': 3, 'username': 'eve'});

      expect(profile.friendCount, 0);
      expect(profile.posts, isEmpty);
      expect(profile.isPrivate, isFalse);
      expect(profile.isLocked, isFalse);

      final weird = UserProfile.fromJson({
        'id': 3,
        'username': 'eve',
        'friendCount': '7',
        'posts': 'nope',
      });
      expect(weird.friendCount, 0);
      expect(weird.posts, isEmpty);
    });
  });

  group('UserProfile.isLocked', () {
    UserProfile make(
            {required bool private, bool friend = false, bool self = false}) =>
        UserProfile.fromJson(
            profileJson(isPrivate: private, isFriend: friend, isSelf: self));

    test('public profiles are never locked', () {
      expect(make(private: false).isLocked, isFalse);
    });

    test('private profiles are locked for strangers', () {
      expect(make(private: true).isLocked, isTrue);
    });

    test('private profiles are open to friends', () {
      expect(make(private: true, friend: true).isLocked, isFalse);
    });

    test('your own private profile is open to you', () {
      expect(make(private: true, self: true).isLocked, isFalse);
    });
  });

  group('FeedPost', () {
    test('copyWith only changes vote fields', () {
      final post = FeedPost.fromJson(postJson(5, upvotes: 1));
      final voted = post.copyWith(upvoteCount: 2, hasUpvoted: true);

      expect(voted.id, 5);
      expect(voted.user.username, 'bob');
      expect(voted.challenge?.title, 'Défi');
      expect(voted.upvoteCount, 2);
      expect(voted.hasUpvoted, isTrue);
    });

    test('detects video posts', () {
      final video = FeedPost.fromJson({...postJson(1), 'mediaType': 'VIDEO'});
      expect(video.isVideo, isTrue);
      expect(FeedPost.fromJson(postJson(2)).isVideo, isFalse);
    });
  });
}
