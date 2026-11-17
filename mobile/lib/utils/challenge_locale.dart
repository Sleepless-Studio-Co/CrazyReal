import '../locale_notifier.dart';

/// Traduction d'un défi dans la langue de l'app, lue dans le champ JSON
/// `translations` (`{ "en": { "title", "description" }, ... }`).
///
/// Les réponses HTTP arrivent déjà traduites par le backend ; ce helper sert
/// pour ce qui passe par les sockets (nouveaux posts en direct, notifications),
/// où le backend ne connaît pas la langue de chaque destinataire.
Map<String, dynamic>? challengeTranslationFor(
  dynamic translations, [
  String? languageCode,
]) {
  if (translations is! Map) return null;
  final translation = translations[languageCode ?? appLocale.value.languageCode];
  return translation is Map ? Map<String, dynamic>.from(translation) : null;
}

/// Copie de [challenge] dont le titre et la description sont traduits si une
/// traduction existe ; le français d'origine sinon.
Map<String, dynamic> localizeChallengeJson(
  Map<String, dynamic> challenge, [
  String? languageCode,
]) {
  final translation =
      challengeTranslationFor(challenge['translations'], languageCode);
  final result = Map<String, dynamic>.from(challenge)..remove('translations');
  if (translation == null) return result;

  final title = translation['title']?.toString() ?? '';
  final description = translation['description']?.toString() ?? '';
  if (title.isNotEmpty) result['title'] = title;
  if (description.isNotEmpty && result.containsKey('description')) {
    result['description'] = description;
  }
  return result;
}

/// Titre à afficher dans une notification de défi.
String localizedNotificationTitle(Map<String, dynamic> payload) {
  final translated =
      challengeTranslationFor(payload['challengeTranslations'])?['title']
          ?.toString();
  if (translated != null && translated.isNotEmpty) return translated;
  return payload['challengeTitle']?.toString() ?? '';
}
