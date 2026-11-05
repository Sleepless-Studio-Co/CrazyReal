import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'auth/auth_service.dart';
import 'l10n/app_localizations.dart';
import 'services/api_exception.dart';
import 'utils/media_url.dart';
import 'widgets/feed_avatar.dart';
import 'widgets/sticker_pop.dart';

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
  bool _isResendingVerification = false;
  bool _isPrivate = false;
  bool _isPrivacySaving = false;
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
      _isPrivate = _user!['isPrivate'] == true;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    // Refresh from the API in the background so the verification status is
    // up to date (e.g. after the user clicked the link in their email).
    await _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    try {
      final fresh = await _authService.fetchProfile();
      if (fresh != null && mounted) {
        setState(() {
          _user = fresh;
          if (!_isEditing) {
            _populateControllers(fresh);
          }
          _syncAvatarFromUser(fresh);
          _isPrivate = fresh['isPrivate'] == true;
        });
      }
    } catch (_) {
      // Non-fatal: keep showing the cached profile.
    }
  }

  bool get _isEmailVerified => _user?['emailVerified'] == true;

  Future<void> _resendVerificationEmail() async {
    if (_isResendingVerification) return;
    setState(() {
      _isResendingVerification = true;
    });

    final l10n = AppLocalizations.of(context)!;
    try {
      await _authService.resendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.verificationEmailSent)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResendingVerification = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      widget.onLoggedOut();
    }
  }

  Future<void> _togglePrivacy(bool value) async {
    setState(() {
      _isPrivacySaving = true;
    });

    try {
      final result = await _authService.updatePrivacy(value);
      final updatedUser = result['user'];
      if (!mounted) return;
      setState(() {
        _isPrivate = updatedUser is Map
            ? updatedUser['isPrivate'] == true
            : value;
        if (updatedUser is Map<String, dynamic>) {
          _user = updatedUser;
        }
      });
    } on UnauthorizedException {
      if (mounted) widget.onUnauthorized();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: popCoral,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPrivacySaving = false;
        });
      }
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
    } on UnauthorizedException {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        widget.onUnauthorized();
      }
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString();
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
    await _selectBaseAvatar(kAvatarOptions.first.id);
  }

  void _handleAvatarError(Object error) {
    if (error is UnauthorizedException) {
      if (mounted) {
        widget.onUnauthorized();
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: popCoral,
      ),
    );
  }

  AvatarOption _resolveAvatarOption() {
    final id = _avatarKey;
    if (id == null) return kAvatarOptions.first;
    return kAvatarOptions.firstWhere(
      (option) => option.id == id,
      orElse: () => kAvatarOptions.first,
    );
  }

  Future<void> _showAvatarPicker() async {
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.chooseAvatar, style: popTitle()),
                const SizedBox(height: 12),
                Text(l10n.baseAvatars.toUpperCase(), style: popLabel()),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: kAvatarOptions
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
                  leading: const PopIconChip(icon: Icons.photo_library_outlined),
                  title: Text(l10n.chooseFromGallery, style: popValue()),
                ),
                if (_avatarUrl != null)
                  ListTile(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _removeCustomAvatar();
                    },
                    leading: const PopIconChip(
                      icon: Icons.delete_outline,
                      color: popDanger,
                    ),
                    title: Text(
                      l10n.removePhoto,
                      style: popValue(color: popDanger),
                    ),
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
      appBar: popAppBar(title: l10n.account),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _buildProfileHeader(l10n),
        const SizedBox(height: 18),
        _buildPrivacyCard(l10n),
        if (!_isEmailVerified) ...[
          const SizedBox(height: 18),
          _buildVerificationBanner(l10n),
        ],
        if (_isEditing) ...[
          const SizedBox(height: 18),
          _buildEditCard(l10n),
        ],
        const SizedBox(height: 22),
        _isEditing ? _buildSaveButtons(l10n) : _buildLogoutButton(l10n),
      ],
    );
  }

  Widget _buildPrivacyCard(AppLocalizations l10n) {
    return _buildCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PopIconChip(icon: _isPrivate ? Icons.lock_outline : Icons.public),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPrivate ? l10n.privateAccount : l10n.publicAccount,
                  style: popValue(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPrivate ? l10n.privateAccountDesc : l10n.publicAccountDesc,
                  style: popMuted(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _isPrivacySaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: _isPrivate,
                  onChanged: _togglePrivacy,
                ),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: popCardDecoration(color: popYellow, radius: 20, shadow: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PopIconChip(
                icon: Icons.mark_email_unread_outlined,
                background: popCard,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.emailNotVerifiedTitle,
                      style: popTitle(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.emailNotVerifiedMessage,
                      style: popBody(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PopButton(
                  onPressed: _resendVerificationEmail,
                  loading: _isResendingVerification,
                  icon: Icons.send_outlined,
                  label: l10n.resendVerificationEmail,
                  color: popInk,
                  dense: true,
                  expand: true,
                ),
              ),
              const SizedBox(width: 10),
              PopIconButton(
                onPressed: _refreshProfile,
                icon: Icons.refresh,
                tooltip: l10n.refresh,
                size: 44,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(AppLocalizations l10n) {
    final username = _user?['username']?.toString() ?? '';
    final email = _user?['email']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: popCardDecoration(radius: 26, shadow: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _showAvatarPicker,
            child: _buildAvatar(size: 88, showBadge: true),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.profile.toUpperCase(), style: popLabel()),
                const SizedBox(height: 4),
                Text(
                  username,
                  style: popTitle(fontSize: 24),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: popMuted(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                PopButton(
                  onPressed: _isSaving ? null : _startEditing,
                  icon: Icons.edit_outlined,
                  label: l10n.edit,
                  color: popYellow,
                  foreground: popInk,
                  dense: true,
                ),
              ],
            ),
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
          Text(l10n.profile.toUpperCase(), style: popLabel()),
          const SizedBox(height: 14),
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: l10n.username),
            textInputAction: TextInputAction.next,
            autocorrect: false,
            style: popValue(fontSize: 16),
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
            decoration: InputDecoration(labelText: l10n.email),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            style: popValue(fontSize: 16),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.pleaseEnterEmail;
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
                return l10n.pleaseEnterValidEmail;
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: popValue(fontSize: 13, color: popDanger),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButtons(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: PopButton(
            onPressed: _saveProfile,
            loading: _isSaving,
            label: l10n.save,
            expand: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PopButton(
            onPressed: _isSaving ? null : _cancelEditing,
            label: l10n.cancel,
            color: popCard,
            foreground: popInk,
            expand: true,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(AppLocalizations l10n) {
    return PopButton(
      onPressed: _logout,
      icon: Icons.logout,
      label: l10n.logout,
      color: popCoral,
      foreground: popInk,
      expand: true,
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: popCardDecoration(radius: 20, shadow: 4),
      child: child,
    );
  }

  Widget _buildAvatar({double size = 96, bool showBadge = false}) {
    final option = _resolveAvatarOption();
    Widget avatarInner;

    if (_pendingAvatarBytes != null) {
      avatarInner = Image.memory(
        _pendingAvatarBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      final resolvedAvatarUrl = resolveMediaUrl(_avatarUrl!)!;
      avatarInner = Image.network(
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
            color: option.background,
            child: Icon(
              option.icon,
              color: option.foreground,
              size: size * 0.45,
            ),
          );
        },
      );
    } else {
      avatarInner = Container(
        width: size,
        height: size,
        color: option.background,
        child: Icon(option.icon, color: option.foreground, size: size * 0.45),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: popCard,
            boxShadow: popShadow(4),
          ),
          // Drawn over the picture so photos get the same ink outline.
          foregroundDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: popInk, width: popStroke),
          ),
          child: ClipOval(child: avatarInner),
        ),
        if (_isAvatarLoading)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.35),
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
            bottom: -2,
            right: -4,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: popPurple,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: popInk, width: 2),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarChoice({
    required AvatarOption option,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6),
          // Lavender rather than yellow, which is also one of the avatars.
          decoration: BoxDecoration(
            color: isSelected ? popBg : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? popInk : Colors.transparent,
              width: popStroke,
            ),
            boxShadow: isSelected ? popShadow(3) : null,
          ),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: option.background,
              border: Border.all(color: popInk, width: popStroke),
            ),
            child: Icon(option.icon, color: option.foreground),
          ),
        ),
      ),
    );
  }
}
