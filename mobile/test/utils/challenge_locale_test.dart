import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/challenge_locale.dart';

void main() {
  const translations = {
    'en': {'title': 'Sunny selfie', 'description': 'In the sun'},
    'es': {'title': 'Selfie soleado', 'description': ''},
  };

  group('localizeChallengeJson', () {
    final challenge = {
      'id': 1,
      'title': 'Selfie au soleil',
      'description': 'Au soleil',
      'translations': translations,
    };

    test('uses the translation of the app language', () {
      expect(localizeChallengeJson(challenge, 'en'), {
        'id': 1,
        'title': 'Sunny selfie',
        'description': 'In the sun',
      });
    });

    test('keeps the French text when the language is not translated', () {
      expect(localizeChallengeJson(challenge, 'fr'), {
        'id': 1,
        'title': 'Selfie au soleil',
        'description': 'Au soleil',
      });
    });

    test('keeps the original description when the translation is empty', () {
      expect(localizeChallengeJson(challenge, 'es')['description'], 'Au soleil');
    });

    test('does not add a description the post challenge did not have', () {
      final postChallenge = {'id': 1, 'title': 'Selfie', 'translations': translations};
      expect(localizeChallengeJson(postChallenge, 'en'), {'id': 1, 'title': 'Sunny selfie'});
    });

    test('handles group challenges without translations', () {
      expect(localizeChallengeJson({'id': 2, 'title': 'Groupe', 'translations': null}, 'en'),
          {'id': 2, 'title': 'Groupe'});
    });
  });

  group('localizedNotificationTitle', () {
    test('prefers the translated title, then the French one', () {
      final payload = {'challengeTitle': 'Selfie au soleil', 'challengeTranslations': translations};
      // La langue par défaut de l'app (appLocale) est l'anglais.
      expect(localizedNotificationTitle(payload), 'Sunny selfie');
      expect(localizedNotificationTitle({'challengeTitle': 'Selfie au soleil'}), 'Selfie au soleil');
    });
  });
}
