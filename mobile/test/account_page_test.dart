import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/account_page.dart';
import 'package:mobile/widgets/feed_avatar.dart';

import 'helpers.dart';

void main() {
  setUp(setUpTestEnv);

  FakeApi accountApi({
    Map<String, http.Response Function(http.Request)> extra = const {},
  }) =>
      FakeApi({
        'GET /auth/me': (_) => json(meJson),
        'GET /users/1': (_) => json(profileJson(
            id: 1,
            username: 'alice',
            friendCount: 3,
            streak: streakJson(current: 2, best: 4))),
        ...extra,
      });

  Future<void> openAccount(WidgetTester tester) async {
    await tester.pumpWidget(wrapApp(AccountPage(
      onLoggedOut: () {},
      onUnauthorized: () {},
    )));
    await tester.pumpAndSettle();
  }

  testWithApi(
    'uses the letter avatar by default',
    accountApi,
    (tester, api) async {
      await openAccount(tester);

      expect(find.text('A'), findsOneWidget);
    },
  );

  testWithApi(
    'can switch back to the default letter avatar',
    () => accountApi(extra: {
      'DELETE /users/me/avatar': (_) => json({'user': meJson}),
    }),
    (tester, api) async {
      await openAccount(tester);

      await tester.tap(find.byType(FeedAvatar));
      await tester.pumpAndSettle();
      expect(find.text('Utiliser ma lettre'), findsOneWidget);

      await tester.tap(find.text('Utiliser ma lettre'));
      await tester.pumpAndSettle();

      expect(api.calls, contains('DELETE /users/me/avatar'));
    },
  );

  testWithApi(
    'still offers the base avatar icons',
    () => accountApi(extra: {
      'PATCH /users/me/avatar': (_) => json({
            'user': {...meJson, 'avatarKey': 'sea'},
          }),
    }),
    (tester, api) async {
      await openAccount(tester);

      await tester.tap(find.byType(FeedAvatar));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.waves_outlined));
      await tester.pumpAndSettle();

      expect(api.calls, contains('PATCH /users/me/avatar'));
      expect(find.byIcon(Icons.waves_outlined), findsOneWidget);
    },
  );
}
