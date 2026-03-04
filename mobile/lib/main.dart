import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'home_page.dart';
import 'friend_page.dart';
import 'new_post_page.dart';
import 'setting_page.dart';
import 'account_page.dart';

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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    FriendPage(),
    NewPage(),
    SettingPage(),
    AccountPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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