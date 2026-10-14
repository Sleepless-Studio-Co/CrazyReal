import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/friend_page.dart';
import 'package:mobile/user_profile_page.dart';
import 'package:mobile/widgets/feed_avatar.dart';

import 'helpers.dart';

void main() {
  setUp(setUpTestEnv);

  FakeApi friendsApi({
    List<Map<String, dynamic>> friends = const [],
    List<Map<String, dynamic>> requests = const [],
  }) =>
      FakeApi({
        'GET /friends': (_) => json(friends),
        'GET /friends/requests': (_) => json(requests),
        'GET /users/2': (_) => json(profileJson(id: 2, username: 'bob')),
        'GET /users/3': (_) => json(profileJson(id: 3, username: 'carol')),
        'PATCH /friends/accept/9': (_) => json({'status': 'ACCEPTED'}),
      });

  Future<void> openFriends(WidgetTester tester) async {
    await tester.pumpWidget(wrapApp(FriendPage(onUnauthorized: () {})));
    await tester.pumpAndSettle();
  }

  testWithApi(
    'lists friends with tab counters',
    () => friendsApi(
      friends: [
        {'id': 2, 'username': 'bob', 'isPrivate': false},
      ],
      requests: [
        {
          'requestId': 9,
          'requester': {'id': 3, 'username': 'carol'}
        },
      ],
    ),
    (tester, api) async {
      await openFriends(tester);

      expect(find.text('bob'), findsOneWidget);
      expect(find.textContaining('(1)'), findsNWidgets(2));
    },
  );

  testWithApi(
    'tapping a friend avatar opens their profile',
    () => friendsApi(friends: [
      {'id': 2, 'username': 'bob', 'isPrivate': true},
    ]),
    (tester, api) async {
      await openFriends(tester);

      await tester.tap(find.byType(FeedAvatar));
      await tester.pumpAndSettle();

      expect(
          tester.widget<UserProfilePage>(find.byType(UserProfilePage)).userId,
          2);
      expect(api.calls.last, 'GET /users/2');
    },
  );

  testWithApi(
    'tapping a requester avatar opens their profile before accepting',
    () => friendsApi(requests: [
      {
        'requestId': 9,
        'requester': {'id': 3, 'username': 'carol'}
      },
    ]),
    (tester, api) async {
      await openFriends(tester);
      await tester.tap(find.textContaining('Demandes'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FeedAvatar));
      await tester.pumpAndSettle();

      expect(
          tester.widget<UserProfilePage>(find.byType(UserProfilePage)).userId,
          3);
    },
  );

  testWithApi(
    'accepting a request reloads the lists',
    () => friendsApi(requests: [
      {
        'requestId': 9,
        'requester': {'id': 3, 'username': 'carol'}
      },
    ]),
    (tester, api) async {
      await openFriends(tester);
      await tester.tap(find.textContaining('Demandes'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(api.calls, contains('PATCH /friends/accept/9'));
      expect(api.calls.where((c) => c == 'GET /friends'), hasLength(2));
    },
  );

  testWithApi(
    'an expired session triggers onUnauthorized',
    () => FakeApi({
      'GET /friends': (_) => json({'message': 'Unauthorized'}, 401),
      'GET /friends/requests': (_) => json({'message': 'Unauthorized'}, 401),
    }),
    (tester, api) async {
      var loggedOut = false;
      await tester.pumpWidget(
          wrapApp(FriendPage(onUnauthorized: () => loggedOut = true)));
      // The page keeps its spinner while the app logs out, so no pumpAndSettle.
      await tester.pump();
      await tester.pump();

      expect(loggedOut, isTrue);
    },
  );
}
