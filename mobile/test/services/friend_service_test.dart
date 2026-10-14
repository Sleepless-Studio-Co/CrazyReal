import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/services/api_exception.dart';
import 'package:mobile/services/friend_service.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<T> withApi<T>(FakeApi api, Future<T> Function() body) =>
      http.runWithClient(body, () => api.client);

  setUp(setUpTestEnv);

  test('getFriends returns the decoded list with the bearer token', () async {
    final api = FakeApi({
      'GET /friends': (_) => json([
            {'id': 2, 'username': 'bob', 'isPrivate': true},
          ]),
    });

    final friends = await withApi(api, () => FriendService().getFriends());

    expect(friends, [
      {'id': 2, 'username': 'bob', 'isPrivate': true},
    ]);
    expect(api.requests.single.headers['Authorization'], 'Bearer tok');
  });

  test('getPendingRequests calls /friends/requests', () async {
    final api = FakeApi({
      'GET /friends/requests': (_) => json([
            {
              'requestId': 4,
              'requester': {'id': 1, 'username': 'alice'},
            },
          ]),
    });

    final requests = await withApi(api, () => FriendService().getPendingRequests());

    expect(requests.single['requestId'], 4);
  });

  test('sendRequest posts to /friends/request/:username and accepts 201', () async {
    final api = FakeApi({'POST /friends/request/bob': (_) => json({'id': 1}, 201)});

    await withApi(api, () => FriendService().sendRequest('bob'));

    expect(api.calls, ['POST /friends/request/bob']);
  });

  test('sendRequest surfaces the backend reason when it fails', () async {
    final api = FakeApi({
      'POST /friends/request/bob': (_) =>
          json({'message': 'Une demande ou une relation existe déjà.'}, 400),
    });

    await expectLater(
      withApi(api, () => FriendService().sendRequest('bob')),
      throwsA(isA<ApiException>().having(
        (e) => e.message,
        'message',
        'Une demande ou une relation existe déjà.',
      )),
    );
  });

  test('acceptRequest and rejectRequest PATCH the right request', () async {
    final api = FakeApi({
      'PATCH /friends/accept/9': (_) => json({'status': 'ACCEPTED'}),
      'PATCH /friends/reject/10': (_) => json({'success': true}),
    });

    await withApi(api, () => FriendService().acceptRequest(9));
    await withApi(api, () => FriendService().rejectRequest(10));

    expect(api.calls, ['PATCH /friends/accept/9', 'PATCH /friends/reject/10']);
  });

  test('blockUser posts to /friends/block/:username', () async {
    final api = FakeApi({'POST /friends/block/bob': (_) => json({'status': 'BLOCKED'}, 201)});

    await withApi(api, () => FriendService().blockUser('bob'));

    expect(api.calls, ['POST /friends/block/bob']);
  });

  test('searchUsers encodes the query', () async {
    final api = FakeApi({'GET /users/search': (_) => json(<dynamic>[])});

    await withApi(api, () => FriendService().searchUsers('jean pierre&co'));

    expect(api.requests.single.url.queryParameters['q'], 'jean pierre&co');
  });

  test('a 401 becomes UnauthorizedException so the app can log out', () async {
    final api = FakeApi({'GET /friends': (_) => json({'message': 'Unauthorized'}, 401)});

    await expectLater(
      withApi(api, () => FriendService().getFriends()),
      throwsA(isA<UnauthorizedException>()),
    );
  });
}
