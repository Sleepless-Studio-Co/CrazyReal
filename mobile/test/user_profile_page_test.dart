import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/user_profile_page.dart';
import 'package:mobile/widgets/post_card.dart';

import 'helpers.dart';

void main() {
  setUp(setUpTestEnv);

  final threePosts = [
    for (var i = 1; i <= 3; i++) postJson(i, challenge: 'Défi $i'),
  ];

  FakeApi profileApi(Map<String, dynamic> profile, [Map<String, http.Response Function(http.Request)> extra = const {}]) =>
      FakeApi({'GET /users/2': (_) => json(profile), ...extra});

  Future<void> openProfile(WidgetTester tester) async {
    await tester.pumpWidget(wrapApp(const UserProfilePage(userId: 2)));
    await tester.pumpAndSettle();
  }

  /// Grid tiles are the only photo Heroes on the profile page.
  Finder gridTiles() => find.byType(Hero);

  group('header', () {
    testWithApi(
      'shows a loader, then the username and counters',
      () => profileApi(profileJson(friendCount: 12, posts: threePosts)),
      (tester, api) async {
        await tester.pumpWidget(wrapApp(const UserProfilePage(userId: 2)));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();

        expect(find.text('bob'), findsNWidgets(2)); // app bar + header
        expect(find.text('3'), findsOneWidget);
        expect(find.text('défis'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('abonnés'), findsOneWidget);
      },
    );

    testWithApi(
      'uses the singular for one follower and one challenge',
      () => profileApi(profileJson(friendCount: 1, posts: [postJson(1)])),
      (tester, api) async {
        await openProfile(tester);

        expect(find.text('abonné'), findsOneWidget);
        expect(find.text('défi'), findsOneWidget);
      },
    );

    testWithApi(
      'shows a lock next to the name of a private account',
      () => profileApi(profileJson(isPrivate: true, isFriend: true, posts: threePosts)),
      (tester, api) async {
        await openProfile(tester);

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(gridTiles(), findsNWidgets(3));
      },
    );
  });

  group('grid', () {
    testWithApi(
      'shows one tile per completed challenge',
      () => profileApi(profileJson(posts: threePosts)),
      (tester, api) async {
        await openProfile(tester);

        expect(gridTiles(), findsNWidgets(3));
        expect(find.byType(GridView), findsNothing, reason: 'built as a sliver');
      },
    );

    testWithApi(
      'marks video posts with a play icon',
      () => profileApi(profileJson(posts: [
        {...postJson(1), 'mediaType': 'VIDEO'},
        postJson(2),
      ])),
      (tester, api) async {
        await openProfile(tester);

        expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
        expect(gridTiles(), findsOneWidget);
      },
    );

    testWithApi(
      'shows an empty state when nothing has been posted',
      () => profileApi(profileJson()),
      (tester, api) async {
        await openProfile(tester);

        expect(find.text('Aucun défi réalisé pour le moment'), findsOneWidget);
        expect(gridTiles(), findsNothing);
      },
    );
  });

  group('private account', () {
    testWithApi(
      'is locked for a non-friend: no posts, no post count, followers still visible',
      () => profileApi(profileJson(isPrivate: true, friendCount: 4)),
      (tester, api) async {
        await openProfile(tester);

        expect(find.text('Ce compte est privé'), findsOneWidget);
        expect(find.text('Deviens ami avec cette personne pour voir ses défis.'), findsOneWidget);
        expect(find.text('défis'), findsNothing);
        expect(find.text('4'), findsOneWidget);
        expect(gridTiles(), findsNothing);
      },
    );

    testWithApi(
      'is open to the owner',
      () => profileApi(profileJson(isPrivate: true, isSelf: true, posts: threePosts)),
      (tester, api) async {
        await openProfile(tester);

        expect(find.text('Ce compte est privé'), findsNothing);
        expect(gridTiles(), findsNWidgets(3));
      },
    );
  });

  group('loading errors', () {
    testWithApi(
      'shows the error and recovers with the retry button',
      () {
        var attempts = 0;
        return FakeApi({
          'GET /users/2': (_) => ++attempts == 1
              ? json({'message': 'Serveur indisponible'}, 503)
              : json(profileJson(posts: threePosts)),
        });
      },
      (tester, api) async {
        await openProfile(tester);

        expect(find.text('Impossible de charger le profil'), findsOneWidget);
        expect(find.text('Serveur indisponible'), findsOneWidget);

        await tester.tap(find.text('Actualiser'));
        await tester.pumpAndSettle();

        expect(find.text('Impossible de charger le profil'), findsNothing);
        expect(gridTiles(), findsNWidgets(3));
        expect(api.requests, hasLength(2));
      },
    );

    testWithApi(
      'pull to refresh fetches the profile again',
      () => profileApi(profileJson(posts: threePosts)),
      (tester, api) async {
        await openProfile(tester);

        await tester.fling(find.text('défis'), const Offset(0, 400), 1000);
        await tester.pumpAndSettle();

        expect(api.calls, ['GET /users/2', 'GET /users/2']);
      },
    );
  });

  group('post list', () {
    Future<void> openTile(WidgetTester tester, int index) async {
      await openProfile(tester);
      await tester.tap(gridTiles().at(index));
      await tester.pumpAndSettle();
    }

    testWithApi(
      'opens on the tapped post',
      () => profileApi(profileJson(posts: threePosts)),
      (tester, api) async {
        await openTile(tester, 2);

        expect(find.text('Défis'), findsOneWidget); // app bar title
        expect(find.text('Défi 3'), findsOneWidget);
        // The tapped post sits at the top of the viewport.
        final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
        final firstCardTop = tester.getTopLeft(find.byType(PostCard).first).dy;
        expect(tester.widget<PostCard>(find.byType(PostCard).first).post.id, 3);
        expect(firstCardTop - appBarBottom, lessThan(20));
      },
    );

    testWithApi(
      'can scroll up to the posts before the tapped one',
      () => profileApi(profileJson(posts: threePosts)),
      (tester, api) async {
        await openTile(tester, 2);

        await tester.scrollUntilVisible(find.text('Défi 1'), -300);

        expect(find.text('Défi 1'), findsOneWidget);
      },
    );

    testWithApi(
      'does not stack the same profile again when tapping the author avatar',
      () => profileApi(profileJson(posts: threePosts)),
      (tester, api) async {
        await openTile(tester, 0);

        expect(tester.widget<PostCard>(find.byType(PostCard).first).linkAvatarToProfile, isFalse);
        expect(find.bySemanticsLabel('Voir le profil de bob'), findsNothing);
      },
    );

    testWithApi(
      'upvoting updates the heart and the counter',
      () => profileApi(profileJson(posts: threePosts), {
        'POST /posts/1/upvote': (_) => json(postJson(1, challenge: 'Défi 1', upvotes: 1, hasUpvoted: true)),
      }),
      (tester, api) async {
        await openTile(tester, 0);

        await tester.tap(find.byIcon(Icons.favorite_border).first);
        await tester.pumpAndSettle();

        expect(api.calls.last, 'POST /posts/1/upvote');
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
      },
    );

    testWithApi(
      'removing an upvote sends DELETE',
      () => profileApi(profileJson(posts: [postJson(1, upvotes: 2, hasUpvoted: true)]), {
        'DELETE /posts/1/upvote': (_) => json(postJson(1, upvotes: 1)),
      }),
      (tester, api) async {
        await openTile(tester, 0);

        await tester.tap(find.byIcon(Icons.favorite));
        await tester.pumpAndSettle();

        expect(api.calls.last, 'DELETE /posts/1/upvote');
        expect(find.byIcon(Icons.favorite), findsNothing);
        expect(find.text('1'), findsOneWidget);
      },
    );

    testWithApi(
      'a failed upvote is rolled back',
      () => profileApi(profileJson(posts: threePosts), {
        'POST /posts/1/upvote': (_) => json({'message': 'boom'}, 500),
      }),
      (tester, api) async {
        await openTile(tester, 0);

        await tester.tap(find.byIcon(Icons.favorite_border).first);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.favorite), findsNothing);
      },
    );

    testWithApi(
      'the vote survives going back to the grid and reopening the list',
      () => profileApi(profileJson(posts: threePosts), {
        'POST /posts/1/upvote': (_) => json(postJson(1, challenge: 'Défi 1', upvotes: 1, hasUpvoted: true)),
      }),
      (tester, api) async {
        await openTile(tester, 0);
        await tester.tap(find.byIcon(Icons.favorite_border).first);
        await tester.pumpAndSettle();

        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        await tester.tap(gridTiles().at(0));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(api.calls.where((c) => c.startsWith('GET')), hasLength(1));
      },
    );
  });
}
