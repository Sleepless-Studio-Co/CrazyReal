import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'auth/auth_service.dart';
import 'l10n/app_localizations.dart';

final String _apiBaseUrl =
  dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

const Color _inkColor = Color(0xFF3B2A21);
const Color _inkMuted = Color(0xFF6A4A3B);
const Color _cardColor = Color(0xFFFFF7E6);
const Color _accentColor = Color(0xFFB85C38);

class _AvatarOption {
  const _AvatarOption({
    required this.id,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String id;
  final Color background;
  final Color foreground;
  final IconData icon;
}

const List<_AvatarOption> _avatarOptions = [
  _AvatarOption(
    id: 'ember',
    background: Color(0xFFE9B384),
    foreground: Color(0xFF3C2A21),
    icon: Icons.whatshot_outlined,
  ),
  _AvatarOption(
    id: 'sea',
    background: Color(0xFF9FC0B9),
    foreground: Color(0xFF1E3D3A),
    icon: Icons.waves_outlined,
  ),
  _AvatarOption(
    id: 'citrus',
    background: Color(0xFFF7E27C),
    foreground: Color(0xFF5E4B0A),
    icon: Icons.emoji_food_beverage_outlined,
  ),
  _AvatarOption(
    id: 'berry',
    background: Color(0xFFD4A5A5),
    foreground: Color(0xFF4D2020),
    icon: Icons.favorite_border,
  ),
  _AvatarOption(
    id: 'noon',
    background: Color(0xFFB1C5E5),
    foreground: Color(0xFF1F2F4A),
    icon: Icons.sports_tennis_outlined,
  ),
  _AvatarOption(
    id: 'terra',
    background: Color(0xFFCBB39B),
    foreground: Color(0xFF4E3722),
    icon: Icons.terrain_outlined,
  ),
];

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
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isAvatarLoading = false;
  String? _errorMessage;
  String? _avatarUrl;
  String? _avatarKey;
  Uint8List? _pendingAvatarBytes;

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
      _syncAvatarFromUser(_user!);
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

  void _syncAvatarFromUser(Map<String, dynamic> user) {
    _avatarUrl = user['avatarUrl']?.toString();
    _avatarKey = user['avatarKey']?.toString();
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

    FocusScope.of(context).unfocus();

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
        _syncAvatarFromUser(updatedUser);
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

  Future<void> _selectBaseAvatar(String id) async {
    setState(() {
      _isAvatarLoading = true;
      _pendingAvatarBytes = null;
    });

    try {
      final result = await _authService.updateAvatarKey(id);
      final updatedUser = result['user'];
      if (updatedUser is Map<String, dynamic>) {
        _user = updatedUser;
        _syncAvatarFromUser(updatedUser);
      }
    } catch (e) {
      _handleAvatarError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isAvatarLoading = false;
        });
      }
    }
  }

  Future<void> _pickCustomAvatar() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      _isAvatarLoading = true;
      _pendingAvatarBytes = bytes;
    });

    try {
      final filename = image.name.isNotEmpty
          ? image.name
          : image.path.split('/').last;
      final result = await _authService.uploadAvatarImage(
        bytes: bytes,
        filename: filename.isEmpty ? 'avatar.jpg' : filename,
      );
      final updatedUser = result['user'];
      if (updatedUser is Map<String, dynamic>) {
        _user = updatedUser;
        _syncAvatarFromUser(updatedUser);
      }
      if (mounted) {
        setState(() {
          _pendingAvatarBytes = null;
        });
      }
    } catch (e) {
      _handleAvatarError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isAvatarLoading = false;
        });
      }
    }
  }

  Future<void> _removeCustomAvatar() async {
    await _selectBaseAvatar(_avatarOptions.first.id);
  }

  void _handleAvatarError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.toLowerCase().contains('unauthorized')) {
      if (mounted) {
        widget.onUnauthorized();
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  _AvatarOption _resolveAvatarOption() {
    final id = _avatarKey;
    if (id == null) return _avatarOptions.first;
    return _avatarOptions.firstWhere(
      (option) => option.id == id,
      orElse: () => _avatarOptions.first,
    );
  }

  Future<void> _showAvatarPicker() async {
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.chooseAvatar,
                  style: _titleStyle(context).copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.baseAvatars,
                  style: _labelStyle(context),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _avatarOptions
                      .map(
                        (option) => _buildAvatarChoice(
                          option: option,
                          isSelected: _avatarUrl == null &&
                              _pendingAvatarBytes == null &&
                              _avatarKey == option.id,
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await _selectBaseAvatar(option.id);
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                ListTile(
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickCustomAvatar();
                  },
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(l10n.chooseFromGallery, style: _valueStyle(context)),
                ),
                if (_avatarUrl != null)
                  ListTile(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _removeCustomAvatar();
                    },
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: Text(l10n.removePhoto, style: _valueStyle(context)),
                  ),
              ],
            ),
          ),
        );
      },
    );
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

    if (_user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.account),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _cancelEditing,
              style: TextButton.styleFrom(textStyle: _labelStyle(context)),
              child: Text(l10n.cancel),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: l10n.edit,
              onPressed: _isSaving ? null : _startEditing,
            ),
        ],
      ),
      body: SafeArea(
        child: _isEditing
            ? Form(
                key: _formKey,
                child: _buildContent(l10n),
              )
            : _buildContent(l10n),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildProfileHeader(l10n),
        const SizedBox(height: 16),
        _isEditing ? _buildEditCard(l10n) : _buildDetailsCard(l10n),
        const SizedBox(height: 16),
        _isEditing ? _buildSaveCard(l10n) : _buildLogoutCard(l10n),
      ],
    );
  }

  Widget _buildProfileHeader(AppLocalizations l10n) {
    final username = _user?['username']?.toString() ?? '';
    final email = _user?['email']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF2D9),
            Color(0xFFF0D0A8),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332E1B0F),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _showAvatarPicker,
                child: _buildAvatar(size: 88, showBadge: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.profile, style: _titleStyle(context)),
                    const SizedBox(height: 6),
                    Text(username, style: _valueStyle(context)),
                    const SizedBox(height: 4),
                    Text(email, style: _mutedStyle(context)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isAvatarLoading ? null : _showAvatarPicker,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(l10n.changePhoto),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _inkColor,
                        backgroundColor: Colors.white.withOpacity(0.7),
                        side: const BorderSide(color: Color(0xFFDFC5A1)),
                        textStyle: _labelStyle(context),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(AppLocalizations l10n) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.profilePhoto, style: _labelStyle(context)),
          const SizedBox(height: 12),
          Center(child: _buildAvatar(size: 110)),
          const SizedBox(height: 20),
          _buildDetailRow(
            icon: Icons.alternate_email,
            label: l10n.username,
            value: _user?['username']?.toString() ?? '',
          ),
          const Divider(height: 28),
          _buildDetailRow(
            icon: Icons.email_outlined,
            label: l10n.email,
            value: _user?['email']?.toString() ?? '',
          ),
        ],
      ),
    );
  }

  Widget _buildEditCard(AppLocalizations l10n) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.profile, style: _labelStyle(context)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _usernameController,
            decoration: _inputDecoration(l10n.username),
            textInputAction: TextInputAction.next,
            autocorrect: false,
            style: _valueStyle(context),
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
            decoration: _inputDecoration(l10n.email),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            style: _valueStyle(context),
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
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: _labelStyle(context).copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveCard(AppLocalizations l10n) {
    return _buildCard(
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: _valueStyle(context),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.save),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _cancelEditing,
              style: OutlinedButton.styleFrom(
                foregroundColor: _inkColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFDFC5A1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: _valueStyle(context),
              ),
              child: Text(l10n.cancel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutCard(AppLocalizations l10n) {
    return _buildCard(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: Text(l10n.logout),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB54132),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: _valueStyle(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0DFC2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2E1B0F),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: _accentColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _labelStyle(context)),
              const SizedBox(height: 4),
              Text(value, style: _valueStyle(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar({double size = 96, bool showBadge = false}) {
    final option = _resolveAvatarOption();
    Widget avatarInner;

    if (_pendingAvatarBytes != null) {
      avatarInner = ClipOval(
        child: Image.memory(
          _pendingAvatarBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      final resolvedAvatarUrl = _resolveMediaUrl(_avatarUrl!);
      avatarInner = ClipOval(
        child: Image.network(
          resolvedAvatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: size,
              height: size,
              color: option.background,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: option.background,
              ),
              child: Icon(
                option.icon,
                color: option.foreground,
                size: size * 0.45,
              ),
            );
          },
        ),
      );
    } else {
      avatarInner = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: option.background,
        ),
        child: Icon(option.icon, color: option.foreground, size: size * 0.45),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size + 8,
          height: size + 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFE8D0B0),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        ClipOval(
          child: Container(
            width: size,
            height: size,
            color: Colors.white,
            child: avatarInner,
          ),
        ),
        if (_isAvatarLoading)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.35),
            ),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        if (showBadge)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
      ],
    );
  }

  String _resolveMediaUrl(String rawUrl) {
    if (rawUrl.isEmpty) return rawUrl;

    final configuredBase = _apiBaseUrl.endsWith('/')
        ? _apiBaseUrl.substring(0, _apiBaseUrl.length - 1)
        : _apiBaseUrl;
    final configuredUri = Uri.tryParse(configuredBase);

    if (rawUrl.startsWith('/')) {
      return '$configuredBase$rawUrl';
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri != null && uri.hasScheme) {
      final host = uri.host.toLowerCase();
      if ((host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') && configuredUri != null) {
        return uri
            .replace(
              scheme: configuredUri.scheme,
              host: configuredUri.host,
              port: configuredUri.hasPort ? configuredUri.port : null,
            )
            .toString();
      }
      return rawUrl;
    }

    return '$configuredBase/$rawUrl';
  }

  Widget _buildAvatarChoice({
    required _AvatarOption option,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _accentColor : const Color(0xFFE0CBA7),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: option.background,
          ),
          child: Icon(option.icon, color: option.foreground),
        ),
      ),
    );
  }

  TextStyle _titleStyle(BuildContext context) {
    return GoogleFonts.dmSerifDisplay(
      color: _inkColor,
      fontSize: 26,
      letterSpacing: 0.2,
    );
  }

  TextStyle _labelStyle(BuildContext context) {
    return GoogleFonts.karla(
      color: _inkMuted,
      fontSize: 13,
      letterSpacing: 0.2,
      fontWeight: FontWeight.w600,
    );
  }

  TextStyle _valueStyle(BuildContext context) {
    return GoogleFonts.karla(
      color: _inkColor,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
  }

  TextStyle _mutedStyle(BuildContext context) {
    return GoogleFonts.karla(
      color: _inkMuted,
      fontSize: 14,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: _labelStyle(context),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7D3B5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accentColor, width: 1.5),
      ),
    );
  }
}
