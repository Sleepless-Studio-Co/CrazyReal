import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/services/api_exception.dart';
import 'package:mobile/services/feed_service.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<T> withApi<T>(FakeApi api, Future<T> Function() body) =>
      http.runWithClient(body, () => api.client);

  group('FeedService.fetchUserProfile', () {
    setUp(setUpTestEnv);

    test('calls GET /users/:id with the bearer token and parses the profile',
        () async {
      final api = FakeApi({
        'GET /users/42': (_) =>
            json(profileJson(id: 42, friendCount: 3, posts: [postJson(1)])),
      });

      final profile =
          await withApi(api, () => FeedService().fetchUserProfile(42));

      expect(profile.user.id, 42);
      expect(profile.friendCount, 3);
      expect(profile.posts, hasLength(1));
      expect(api.requests.single.url.toString(), 'http://api.test/users/42');
      expect(api.requests.single.headers['Authorization'], 'Bearer tok');
    });

    test('throws UnauthorizedException on 401', () async {
      final api = FakeApi({
        'GET /users/42': (_) => json({'message': 'Unauthorized'}, 401)
      });

      await expectLater(
        withApi(api, () => FeedService().fetchUserProfile(42)),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('surfaces the backend message on 404', () async {
      final api = FakeApi({
        'GET /users/42': (_) => json({'message': 'user not found'}, 404)
      });

      await expectLater(
        withApi(api, () => FeedService().fetchUserProfile(42)),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'user not found')
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('does not call the API without a session', () async {
      setUpTestEnv(token: null);
      final api = FakeApi({});

      await expectLater(
        withApi(api, () => FeedService().fetchUserProfile(42)),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(api.requests, isEmpty);
    });
  });

  group('FeedService upvotes', () {
    setUp(setUpTestEnv);

    test('upvotePost sends POST and removeUpvote sends DELETE', () async {
      final api = FakeApi({
        'POST /posts/7/upvote': (_) =>
            json(postJson(7, upvotes: 1, hasUpvoted: true)),
        'DELETE /posts/7/upvote': (_) => json(postJson(7)),
      });

      final up = await withApi(api, () => FeedService().upvotePost(7));
      final down = await withApi(api, () => FeedService().removeUpvote(7));

      expect(up.hasUpvoted, isTrue);
      expect(down.hasUpvoted, isFalse);
      expect(api.calls, ['POST /posts/7/upvote', 'DELETE /posts/7/upvote']);
    });
  });
}
