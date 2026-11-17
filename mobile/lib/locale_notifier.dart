import 'package:flutter/material.dart';

final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en', ''));

/// Header envoyé au backend pour recevoir les défis dans la langue de l'app
/// (traductions DeepL côté serveur ; le français d'origine sinon).
Map<String, String> localeHeaders() =>
    {'Accept-Language': appLocale.value.languageCode};
