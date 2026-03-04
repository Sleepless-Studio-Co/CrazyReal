import 'package:flutter/material.dart';
import 'auth/auth_service.dart';
import 'auth/login_page.dart';
import 'auth/register_page.dart';
import 'l10n/app_localizations.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _authService = AuthService();
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      _user = await _authService.getUser();
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    setState(() {
      _user = null;
    });
  }

  void _navigateToLogin() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
    if (result == true) {
      _checkAuthStatus();
    }
  }

  void _navigateToRegister() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
    if (result == true) {
      _checkAuthStatus();
    }
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

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.account),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _user != null ? _buildUserProfile() : _buildAuthPrompt(),
      ),
    );
  }

  Widget _buildUserProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.profile,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text('${AppLocalizations.of(context)!.usernameLabel}${_user!['username']}'),
        Text('${AppLocalizations.of(context)!.emailLabel}${_user!['email']}'),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(AppLocalizations.of(context)!.logout),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context)!.welcomeMessage,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(AppLocalizations.of(context)!.pleaseLoginOrRegister),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToLogin,
              child: Text(AppLocalizations.of(context)!.login),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _navigateToRegister,
              child: Text(AppLocalizations.of(context)!.register),
            ),
          ),
        ],
      ),
    );
  }
}