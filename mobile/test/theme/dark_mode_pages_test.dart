import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/admin/admin_page.dart';
import 'package:mobile/account_page.dart';
import 'package:mobile/auth/login_page.dart';
import 'package:mobile/auth/register_page.dart';
import 'package:mobile/chat/chat_list_page.dart';
import 'package:mobile/chat/chat_room_page.dart';
import 'package:mobile/chat/create_group_page.dart';
import 'package:mobile/chat/group_challenges_tab.dart';
import 'package:mobile/chat/group_feed_tab.dart';
import 'package:mobile/chat/group_members_page.dart';
import 'package:mobile/friend_page.dart';
import 'package:mobile/home_page.dart';
import 'package:mobile/setting_page.dart';
import 'package:mobile/user_profile_page.dart';
import 'package:mobile/widgets/paper.dart';

import '../helpers.dart';
import 'contrast_audit.dart';

/// Conformity: every screen must be readable (WCAG AA) in light AND dark
/// mode, and must actually switch to the dark palette.
void main() {
  setUp(setUpTestEnv);

  final posts = [
    for (var i = 1; i <= 4; i++) postJson(i, challenge: 'Défi $i', upvotes: i)
  ];
  final friend = {'id': 2, 'username': 'bob', 'isPrivate': true};
  final request = {
    'requestId': 9,
    'requester': {'id': 3, 'username': 'carol'},
  };
  final members = [
    {
      'role': 'ADMIN',
      'user': {'id': 1, 'username': 'alice'}
    },
    {
      'role': 'MEMBER',
      'user': {'id': 2, 'username': 'bob'}
    },
  ];
  final now = DateTime.now();
  final challenges = [
    {
      'id': 1,
      'title': 'Photo du coucher de soleil',
      'description': 'En groupe',
      'date': now.subtract(const Duration(hours: 1)).toIso8601String(),
      'endsAt': now.add(const Duration(days: 1)).toIso8601String(),
    },
    {
      'id': 2,
      'title': 'Ancien défi',
      'description': '',
      'date': now.subtract(const Duration(days: 9)).toIso8601String(),
      'endsAt': now.subtract(const Duration(days: 2)).toIso8601String(),
    },
  ];

  FakeApi api() => FakeApi({
        'GET /users/2': (_) => json(profileJson(
            friendCount: 12, isPrivate: true, isFriend: true, posts: posts)),
        'GET /users/3': (_) => json(profileJson(
            id: 3, username: 'carol', isPrivate: true, friendCount: 4)),
        'GET /users/4': (_) => json(profileJson(id: 4, username: 'dan')),
        'GET /friends': (_) => json([friend]),
        'GET /friends/requests': (_) => json([request]),
        'GET /users/search': (_) => json([
              {'id': 5, 'username': 'eve', 'isPrivate': true},
              {'id': 6, 'username': 'frank', 'isPrivate': false},
            ]),
        'GET /chat/7/members': (_) => json(members),
        'GET /chat/7/challenges': (_) => json(challenges),
        'GET /chat/7/feed': (_) => json(posts),
        'GET /auth/me': (_) => json(meJson),
        'GET /posts': (_) => json(posts),
        'GET /challenges/available': (_) => json([
              {'id': 1, 'title': 'Défi 1', 'group': null},
            ]),
        'GET /challenge/current': (_) =>
            json({'title': 'Défi du jour', 'description': 'Souris !'}),
        'GET /chat': (_) => json([
              {
                'id': 7,
                'isGroup': true,
                'name': 'Les copains',
                'participants': members,
              },
              {
                'id': 8,
                'isGroup': false,
                'name': null,
                'participants': [
                  {
                    'user': {'id': 1, 'username': 'alice'}
                  },
                  {
                    'user': {'id': 2, 'username': 'bob'}
                  },
                ],
              },
            ]),
        'GET /chat/7/messages': (_) => json([
              {
                'id': 1,
                'content': 'Salut !',
                'createdAt': now.toIso8601String(),
                'senderId': 2,
                'sender': {'id': 2, 'username': 'bob'},
              },
              {
                'id': 2,
                'content': 'Hello',
                'createdAt': now.toIso8601String(),
                'senderId': 1,
                'sender': {'id': 1, 'username': 'alice'},
              },
            ]),
        'GET /admin/challenges': (_) => json([
              {
                'id': 1,
                'title': 'Défi global',
                'description': 'Description',
                'type': 'WEEKLY_A',
                'date': now.toIso8601String(),
                'isActive': true,
                'durationHours': 24,
                '_count': {'posts': 3},
              },
            ]),
      });

  /// Each screen is rendered in both modes; [open] may navigate further.
  void audit(
    String screen,
    Widget page, {
    required Finder shows,
    Future<void> Function(WidgetTester tester)? open,
  }) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWithApi('$screen is readable in ${mode.name} mode', api,
          (tester, _) async {
        await tester.pumpWidget(wrapApp(page, themeMode: mode));
        await tester.pumpAndSettle();
        await open?.call(tester);
        await tester.pumpAndSettle();

        // Guards against auditing a spinner or an error screen by mistake.
        expect(shows, findsWidgets,
            reason: '$screen did not render its content');
        await expectReadable(tester, '$screen (${mode.name})');

        if (mode == ThemeMode.dark) {
          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
          final bg = scaffold.backgroundColor ??
              Theme.of(tester.element(find.byType(Scaffold).last))
                  .scaffoldBackgroundColor;
          expect(bg, PaperColors.dark.bg,
              reason: '$screen keeps a light background in dark mode');
        }
      });
    }
  }

  audit('Public profile', const UserProfilePage(userId: 2),
      shows: find.byType(Hero));
  audit('Locked private profile', const UserProfilePage(userId: 3),
      shows: find.text('Ce compte est privé'));
  audit('Empty profile', const UserProfilePage(userId: 4),
      shows: find.text('Aucun défi réalisé pour le moment'));
  audit('Profile post list', const UserProfilePage(userId: 2),
      shows: find.text('Défi 1'), open: (tester) async {
    await tester.tap(find.byType(Hero).first);
  });
  audit('Friends', FriendPage(onUnauthorized: () {}), shows: find.text('bob'));
  audit('Friend requests', FriendPage(onUnauthorized: () {}),
      shows: find.text('carol'), open: (tester) async {
    await tester.tap(find.textContaining('Demandes'));
  });
  audit('Add friend sheet', FriendPage(onUnauthorized: () {}),
      shows: find.text('frank'), open: (tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'e');
    await tester.pump(const Duration(seconds: 1));
  });
  audit('Create group', const CreateGroupPage(), shows: find.text('bob'));
  audit('Group members', const GroupMembersPage(conversationId: 7),
      shows: find.text('bob'));
  audit('Group challenges',
      const Scaffold(body: GroupChallengesTab(conversationId: 7)),
      shows: find.text('Photo du coucher de soleil'));
  audit('Group feed', const Scaffold(body: GroupFeedTab(conversationId: 7)),
      shows: find.text('Défi 1'));
  audit('Feed', HomePage(onUnauthorized: () {}), shows: find.text('Défi 1'));
  audit('Conversations', const ChatListPage(), shows: find.text('Les copains'));
  audit(
    'Group chat',
    const ChatRoomPage(
        conversationId: 7, conversationName: 'Les copains', isGroup: true),
    shows: find.text('Salut !'),
  );
  audit('Settings', SettingPage(onLoggedOut: () {}, onUnauthorized: () {}),
      shows: find.text('Administration'));
  audit('Account', AccountPage(onLoggedOut: () {}, onUnauthorized: () {}),
      shows: find.text('alice@example.com'));
  audit('Admin', AdminPage(onUnauthorized: () {}),
      shows: find.text('Défi global'));
  audit('Login', const LoginPage(), shows: find.byType(TextField));
  audit('Register', const RegisterPage(), shows: find.byType(TextField));
}
