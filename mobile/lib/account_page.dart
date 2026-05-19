import 'package:flutter/material.dart';
import 'auth/auth_service.dart';
import 'l10n/app_localizations.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.onLoggedOut,
    required this.onUnauthorized,
  });

  final VoidCallback onLoggedOut;
  final VoidCallback onUnauthorized;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (!isLoggedIn) {
      if (mounted) {
        widget.onUnauthorized();
      }
      return;
    }

    _user = await _authService.getUser();

    if (_user == null && mounted) {
      widget.onUnauthorized();
      return;
    }

    if (_user != null) {
      _populateControllers(_user!);
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      widget.onLoggedOut();
    }
  }

  void _populateControllers(Map<String, dynamic> user) {
    _usernameController.text = user['username']?.toString() ?? '';
    _emailController.text = user['email']?.toString() ?? '';
  }

  void _startEditing() {
    if (_user == null) return;
    _populateControllers(_user!);
    setState(() {
      _isEditing = true;
      _errorMessage = null;
    });
  }

  void _cancelEditing() {
    if (_user != null) {
      _populateControllers(_user!);
    }
    setState(() {
      _isEditing = false;
      _errorMessage = null;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_user == null) return;

    final newUsername = _usernameController.text.trim();
    final newEmail = _emailController.text.trim();
    final currentUsername = _user!['username']?.toString() ?? '';
    final currentEmail = _user!['email']?.toString() ?? '';
    final hasUsernameChange = newUsername != currentUsername;
    final hasEmailChange = newEmail != currentEmail;

    if (!hasUsernameChange && !hasEmailChange) {
      setState(() {
        _isEditing = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.updateProfile(
        email: hasEmailChange ? newEmail : null,
        username: hasUsernameChange ? newUsername : null,
      );

      final updatedUser = result['user'];
      if (updatedUser is Map<String, dynamic>) {
        _user = updatedUser;
      }

      if (!mounted) return;

      setState(() {
        _isEditing = false;
        _isSaving = false;
      });

      if (_user != null) {
        _populateControllers(_user!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.profileUpdated)),
      );
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (message.toLowerCase().contains('unauthorized')) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          widget.onUnauthorized();
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = message;
      });
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
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: AppLocalizations.of(context)!.edit,
              onPressed: _startEditing,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isEditing ? _buildEditProfile() : _buildUserProfile(),
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

  Widget _buildEditProfile() {
    final l10n = AppLocalizations.of(context)!;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profile,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: l10n.username,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.pleaseEnterUsername;
                }
                if (value.trim().length < 3) {
                  return l10n.usernameTooShort;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: l10n.email,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.pleaseEnterEmail;
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                  return l10n.pleaseEnterValidEmail;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : Text(l10n.save),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isSaving ? null : _cancelEditing,
                child: Text(l10n.cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
