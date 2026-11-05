import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'locale_notifier.dart';
import 'home_page.dart';
import 'friend_page.dart';
import 'new_post_page.dart';
import 'setting_page.dart';
import 'account_page.dart';
import 'auth/auth_service.dart';
import 'auth/login_page.dart';
import 'services/chat_socket_service.dart';
import 'services/notification_service.dart';
import 'services/global_notification_service.dart';
import 'widgets/sticker_pop.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final prefs = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('app_locale') ?? 'en';
  appLocale.value = Locale(savedLang, '');
  await NotificationService().init(navKey: navigatorKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'CrazyReal',
          locale: locale,
          // Sticker Pop only exists in light: no dark theme on purpose.
          theme: buildStickerPopTheme(),
          // Dark status bar icons on screens without an app bar (home,
          // camera, login); app bars and full-screen viewers set their own.
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
            child: child!,
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
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  final ChatSocketService _chatSocket = ChatSocketService();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    NotificationService().requestPermissions();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopLogo(fontSize: 32),
              SizedBox(height: 32),
              CircularProgressIndicator(),
            ],
          ),
        ),
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
      bottomNavigationBar: PopNavBar(
        items: [
          PopNavItem(icon: Icons.home_outlined, label: l10n.home),
          PopNavItem(icon: Icons.people_outline, label: l10n.friends),
          PopNavItem(
            icon: Icons.photo_camera_outlined,
            label: l10n.newPost,
            primary: true,
          ),
          PopNavItem(icon: Icons.settings_outlined, label: l10n.settings),
          PopNavItem(icon: Icons.person_outline, label: l10n.account),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
