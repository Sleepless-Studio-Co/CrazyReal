import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/feed_post.dart';
import 'package:mobile/user_profile_page.dart';
import 'package:mobile/widgets/feed_avatar.dart';
import 'package:mobile/widgets/post_card.dart';

import '../helpers.dart';

void main() {
  setUp(setUpTestEnv);

  Widget card({bool link = true, VoidCallback? onUpvote}) => wrapApp(Scaffold(
        body: SingleChildScrollView(
          child: PostCard(
            post: FeedPost.fromJson(postJson(1, userId: 7, username: 'carol')),
            unknownUserLabel: 'Utilisateur inconnu',
            onUpvote: onUpvote,
            linkAvatarToProfile: link,
          ),
        ),
      ));

  testWithApi(
    'tapping the author avatar in the feed opens their profile',
    () => FakeApi(
        {'GET /users/7': (_) => json(profileJson(id: 7, username: 'carol'))}),
    (tester, api) async {
      await tester.pumpWidget(card());

      await tester.tap(find.byType(FeedAvatar));
      await tester.pumpAndSettle();

      expect(
          tester.widget<UserProfilePage>(find.byType(UserProfilePage)).userId,
          7);
      expect(api.calls, ['GET /users/7']);
    },
  );

  testWithApi(
    'linkAvatarToProfile: false keeps the avatar inert',
    () => FakeApi({}),
    (tester, api) async {
      await tester.pumpWidget(card(link: false));

      await tester.tap(find.byType(FeedAvatar));
      await tester.pumpAndSettle();

      expect(find.byType(UserProfilePage), findsNothing);
      expect(api.requests, isEmpty);
    },
  );

  testWithApi(
    'shows the author, the challenge and calls onUpvote',
    () => FakeApi({}),
    (tester, api) async {
      var upvotes = 0;
      await tester.pumpWidget(card(onUpvote: () => upvotes++));

      expect(find.text('carol'), findsOneWidget);
      expect(find.text('Défi'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border));
      expect(upvotes, 1);
    },
  );
}
