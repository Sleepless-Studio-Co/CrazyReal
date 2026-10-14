import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/l10n/app_localizations.dart';

/// Fake backend: map "METHOD /path" to a handler, and keep every request so
/// tests can assert on what the app actually sent.
class FakeApi {
  FakeApi(this.routes);

  final Map<String, http.Response Function(http.Request)> routes;
  final List<http.Request> requests = [];

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final key = '${request.method} ${request.url.path}';
    final handler = routes[key];
    if (handler == null) return http.Response('{"message":"no route $key"}', 404);
    return handler(request);
  });

  List<String> get calls =>
      requests.map((r) => '${r.method} ${r.url.path}').toList();
}

http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Environment shared by every test: base URL, a stored session token, and
/// no font downloads from the test runner.
void setUpTestEnv({String? token = 'tok'}) {
  dotenv.testLoad(fileInput: 'API_BASE_URL=http://api.test');
  SharedPreferences.setMockInitialValues({if (token != null) 'access_token': token});
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// A widget test whose `package:http` calls are answered by [api].
void testWithApi(
  String description,
  FakeApi Function() api,
  Future<void> Function(WidgetTester tester, FakeApi api) body,
) {
  testWidgets(description, (tester) async {
    usePhoneScreen(tester);
    final fake = api();
    await http.runWithClient(() => body(tester, fake), () => fake.client);
  });
}

Widget wrapApp(Widget child) => MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

Map<String, dynamic> postJson(
  int id, {
  int userId = 2,
  String username = 'bob',
  String challenge = 'Défi',
  int upvotes = 0,
  bool hasUpvoted = false,
}) =>
    {
      'id': id,
      'photoUrl': '/uploads/$id.jpg',
      'mediaType': 'PHOTO',
      'createdAt': '2026-10-01T10:00:00.000Z',
      'user': {'id': userId, 'username': username},
      'challenge': {'id': id, 'title': challenge, 'type': 'WEEKLY_A'},
      'upvoteCount': upvotes,
      'hasUpvoted': hasUpvoted,
    };

Map<String, dynamic> profileJson({
  int id = 2,
  String username = 'bob',
  bool isPrivate = false,
  bool isFriend = false,
  bool isSelf = false,
  int friendCount = 0,
  List<Map<String, dynamic>> posts = const [],
}) =>
    {
      'id': id,
      'username': username,
      'avatarUrl': null,
      'avatarKey': null,
      'isPrivate': isPrivate,
      'isFriend': isFriend,
      'isSelf': isSelf,
      'friendCount': friendCount,
      'posts': posts,
    };

/// iPhone-sized viewport, so a 4:5 post card fits on screen like on a device.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
