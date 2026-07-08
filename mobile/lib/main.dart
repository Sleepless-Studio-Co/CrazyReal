import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'home_page.dart';
import 'friend_page.dart';
import 'new_post_page.dart';
import 'setting_page.dart';
import 'account_page.dart';
import 'auth/auth_service.dart';
import 'auth/login_page.dart';
import 'services/chat_socket_service.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrazyReal',
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
      home: const AuthGate(),
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
  }

  Future<void> _checkAuth() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (!mounted) return;

    if (isLoggedIn) _chatSocket.connect();

    setState(() {
      _isAuthenticated = isLoggedIn;
      _isLoading = false;
    });
  }

  void _handleAuthSuccess() {
    if (!mounted) return;
    _chatSocket.connect();
    setState(() {
      _isAuthenticated = true;
    });
  }

  Future<void> _handleUnauthorized() async {
    final refreshed = await _authService.restoreSession();
    if (!mounted) return;

    if (refreshed) {
      _chatSocket.connect();
      setState(() {
        _isAuthenticated = true;
      });
      return;
    }

    await _handleLogout();
  }

  Future<void> _handleLogout() async {
    _chatSocket.disconnect();
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

    if (!_isAuthenticated) {
      return LoginPage(onAuthSuccess: _handleAuthSuccess);
    }

    return MainScreen(
      onLoggedOut: () => _handleLogout(),
      onUnauthorized: () => _handleUnauthorized(),
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
      const SettingPage(),
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
