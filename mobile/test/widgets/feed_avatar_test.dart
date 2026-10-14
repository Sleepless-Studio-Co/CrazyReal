import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/user_profile_page.dart';
import 'package:mobile/widgets/feed_avatar.dart';

import '../helpers.dart';

void main() {
  setUp(setUpTestEnv);

  FakeApi profileApi() => FakeApi({'GET /users/2': (_) => json(profileJson())});

  testWithApi('without userId the avatar is not tappable', profileApi, (tester, api) async {
    await tester.pumpWidget(wrapApp(const Scaffold(body: FeedAvatar(username: 'bob'))));

    expect(find.byType(InkWell), findsNothing);
    expect(find.bySemanticsLabel('Voir le profil de bob'), findsNothing);
  });

  testWithApi('a non-positive userId is ignored', profileApi, (tester, api) async {
    await tester.pumpWidget(
      wrapApp(const Scaffold(body: FeedAvatar(username: 'bob', userId: 0))),
    );

    expect(find.byType(InkWell), findsNothing);
  });

  testWithApi('tapping the avatar opens the profile of that user', profileApi, (tester, api) async {
    await tester.pumpWidget(
      wrapApp(const Scaffold(body: FeedAvatar(username: 'bob', userId: 2))),
    );

    await tester.tap(find.byType(FeedAvatar));
    await tester.pumpAndSettle();

    final page = tester.widget<UserProfilePage>(find.byType(UserProfilePage));
    expect(page.userId, 2);
    expect(api.calls, ['GET /users/2']);
  });

  testWithApi('screen readers announce it as a button', profileApi, (tester, api) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapApp(const Scaffold(body: FeedAvatar(username: 'bob', userId: 2))),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Voir le profil de bob')),
      matchesSemantics(
        label: 'Voir le profil de bob',
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('falls back to the initial when there is no photo', (tester) async {
    setUpTestEnv();
    await tester.pumpWidget(wrapApp(const Scaffold(body: FeedAvatar(username: 'bob'))));

    expect(find.text('B'), findsOneWidget);
  });
}
