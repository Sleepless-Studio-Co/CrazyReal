import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/admin/challenge_translations_page.dart';
import 'package:mobile/services/admin_service.dart';

import '../helpers.dart';

void main() {
  setUp(setUpTestEnv);

  Map<String, dynamic> challengeJson(Map<String, dynamic> translations) => {
        'id': 7,
        'title': 'Selfie au soleil',
        'description': 'Au soleil',
        'date': '2026-11-17T10:00:00.000Z',
        'type': 'WEEKLY_A',
        'isActive': true,
        'translations': translations,
      };

  final initial = challengeJson({
    'en': {'title': 'Sunny selfie', 'description': 'In the sun'},
    'es': {'title': 'Selfi', 'description': 'Al sol', 'manual': true},
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(wrapApp(ChallengeTranslationsPage(
      challenge: AdminChallenge.fromJson(initial),
      onUnauthorized: () {},
    )));
    await tester.pumpAndSettle();
  }

  test('AdminChallenge parses translations', () {
    final challenge = AdminChallenge.fromJson(initial);
    expect(challenge.translations['en']!.title, 'Sunny selfie');
    expect(challenge.translations['en']!.manual, isFalse);
    expect(challenge.translations['es']!.manual, isTrue);
    expect(challenge.translations.containsKey('de'), isFalse);
  });

  testWithApi(
    'shows the status of every language',
    () => FakeApi({}),
    (tester, api) async {
      await open(tester);

      expect(find.text('Selfie au soleil'), findsOneWidget);
      expect(find.text('Automatique'), findsOneWidget);
      expect(find.text('Corrigée à la main'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Deutsch'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // pt et de n'ont pas de traduction.
      expect(find.text('Pas traduit : le français est affiché'), findsNWidgets(2));
    },
  );

  testWithApi(
    'saves an edited translation as manual',
    () => FakeApi({
      'PUT /admin/challenges/7/translations/en': (request) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return json(challengeJson({
          'en': {...body, 'manual': true},
        }));
      },
    }),
    (tester, api) async {
      await open(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Sunny selfie'), 'Selfie in the sun');
      await tester.tap(find.text('Enregistrer').first);
      await tester.pumpAndSettle();

      expect(api.calls, ['PUT /admin/challenges/7/translations/en']);
      expect(jsonDecode(api.requests.single.body), {
        'title': 'Selfie in the sun',
        'description': 'In the sun',
      });
      expect(find.text('Traduction enregistrée'), findsOneWidget);
    },
  );

  testWithApi(
    'goes back to the automatic translation',
    () => FakeApi({
      'DELETE /admin/challenges/7/translations/es': (_) => json(challengeJson({
            'es': {'title': 'Selfie al sol', 'description': 'Al sol'},
          })),
    }),
    (tester, api) async {
      await open(tester);

      await tester.tap(find.text("Revenir à l'auto").first);
      await tester.pumpAndSettle();

      expect(api.calls, ['DELETE /admin/challenges/7/translations/es']);
      expect(find.widgetWithText(TextField, 'Selfie al sol'), findsOneWidget);
      expect(find.text('Traduction automatique rétablie'), findsOneWidget);
    },
  );

  testWithApi(
    'refuses an empty title',
    () => FakeApi({}),
    (tester, api) async {
      await open(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Sunny selfie'), '  ');
      await tester.tap(find.text('Enregistrer').first);
      await tester.pumpAndSettle();

      expect(api.calls, isEmpty);
    },
  );
}
