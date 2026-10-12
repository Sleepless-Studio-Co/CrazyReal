import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'l10n/app_localizations.dart';
import 'locale_notifier.dart';
import 'home_page.dart';
import 'friend_page.dart';
import 'new_post_page.dart';
import 'setting_page.dart';
import 'account_page.dart';
import 'auth/auth_service.dart';
import 'auth/login_page.dart';
import 'guest_share_page.dart';
import 'services/chat_socket_service.dart';
import 'services/notification_service.dart';
import 'services/global_notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final prefs = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('app_locale') ?? 'en';
  appLocale.value = Locale(savedLang, '');
  await NotificationService().init(navKey: navigatorKey);
  final initialShareToken = await _readInitialShareToken();
  runApp(MyApp(initialShareToken: initialShareToken));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialShareToken});

  final String? initialShareToken;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'CrazyReal',
          locale: locale,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            scaffoldBackgroundColor: const Color(0xFFF7EBD1),
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
            Locale('fr', ''),
          ],
          home: AuthGate(initialShareToken: initialShareToken),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.initialShareToken});

  final String? initialShareToken;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  final ChatSocketService _chatSocket = ChatSocketService();
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _shareToken;
  StreamSubscription<Uri>? _shareLinkSubscription;

  @override
  void initState() {
    super.initState();
    _shareToken = widget.initialShareToken;
    _shareLinkSubscription = AppLinks().uriLinkStream.listen((uri) {
      final token = _shareTokenFromUri(uri);
      if (token != null && mounted && !_isAuthenticated) {
        setState(() => _shareToken = token);
      }
    });
    _checkAuth();
    NotificationService().requestPermissions();
  }

  @override
  void dispose() {
    _shareLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (!mounted) return;

    if (isLoggedIn) {
      _chatSocket.connect();
      GlobalNotificationService().connect();
    }

    setState(() {
      _isAuthenticated = isLoggedIn;
      _isLoading = false;
    });
  }

  void _handleAuthSuccess() {
    if (!mounted) return;
    _chatSocket.connect();
    GlobalNotificationService().connect();
    setState(() {
      _isAuthenticated = true;
      _shareToken = null;
    });
  }

  Future<void> _handleLogoutOrUnauthorized() async {
    _chatSocket.disconnect();
    GlobalNotificationService().disconnect();
    await _authService.logout();
    if (!mounted) return;

    setState(() {
      _isAuthenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_shareToken != null) {
      return GuestSharePage(
        token: _shareToken!,
        isAuthenticated: _isAuthenticated,
        onAuthSuccess: _handleAuthSuccess,
      );
    }

    if (!_isAuthenticated) {
      return LoginPage(onAuthSuccess: _handleAuthSuccess);
    }

    return MainScreen(
      onLoggedOut: () => _handleLogoutOrUnauthorized(),
      onUnauthorized: () => _handleLogoutOrUnauthorized(),
    );
  }
}

Future<String?> _readInitialShareToken() async {
  final uri = await AppLinks().getInitialLink();
  return _shareTokenFromUri(uri);
}

String? _shareTokenFromUri(Uri? uri) {
  if (uri == null) return null;
  if (uri.scheme == 'crazyreal' && uri.host == 'share') {
    return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  }
  if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'share') {
    return uri.pathSegments[1];
  }
  return null;
}

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.onLoggedOut,
    required this.onUnauthorized,
  });

  final VoidCallback onLoggedOut;
  final VoidCallback onUnauthorized;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<HomePageState> _homeKey = GlobalKey<HomePageState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      HomePage(
        key: _homeKey,
        onUnauthorized: widget.onUnauthorized,
        onPublishTap: () => _onItemTapped(2),
      ),
      FriendPage(onUnauthorized: widget.onUnauthorized),
      NewPage(
        onUnauthorized: widget.onUnauthorized,
        onPostCreated: _onPostCreated,
      ),
      SettingPage(
        onLoggedOut: widget.onLoggedOut,
        onUnauthorized: widget.onUnauthorized,
      ),
      AccountPage(
        onLoggedOut: widget.onLoggedOut,
        onUnauthorized: widget.onUnauthorized,
      ),
    ];
  }

  void _onPostCreated() {
    _homeKey.currentState?.refreshFeed(showLoading: false);
    _onItemTapped(0);
  }

  void _onItemTapped(int index) {
    final previousIndex = _selectedIndex;
    setState(() {
      _selectedIndex = index;
    });

    if (previousIndex == 0 && index != 0) {
      _homeKey.currentState?.setActive(false);
    }
    if (index == 0) {
      _homeKey.currentState?.setActive(true);
      _homeKey.currentState?.refreshFeed(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: l10n.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people),
            label: l10n.friends,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.add_box_outlined),
            label: l10n.newPost,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_circle),
            label: l10n.account,
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[500],
        backgroundColor: const Color(0xFFF7EBD1),
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}
