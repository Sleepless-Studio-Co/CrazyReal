import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'auth/auth_service.dart';
import 'l10n/app_localizations.dart';
import 'models/feed_post.dart';
import 'models/user_streak.dart';
import 'services/api_exception.dart';
import 'services/feed_service.dart';
import 'widgets/feed_avatar.dart';
import 'widgets/paper.dart';
import 'widgets/profile_header.dart';
import 'widgets/streak_card.dart';

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
  final _feedService = FeedService();
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
  UserProfile? _publicProfile;

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

    await _loadPublicProfile(_user?['id']);
  }

  Future<void> _loadPublicProfile(dynamic userId) async {
    if (userId is! int) return;

    try {
      final profile = await _feedService.fetchUserProfile(userId);
      if (!mounted) return;
      setState(() => _publicProfile = profile);
    } on UnauthorizedException {
      if (mounted) widget.onUnauthorized();
    } catch (_) {
      // Non-fatal: stats and streak are optional on the account tab.
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
        _isPrivate =
            updatedUser is Map ? updatedUser['isPrivate'] == true : value;
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
          backgroundColor: Colors.red,
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
      final filename =
          image.name.isNotEmpty ? image.name : image.path.split('/').last;
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

  Future<void> _clearAvatar() async {
    setState(() {
      _isAvatarLoading = true;
      _pendingAvatarBytes = null;
    });

    try {
      final result = await _authService.clearAvatar();
      final updatedUser = result['user'];
      if (updatedUser is Map<String, dynamic>) {
        _user = updatedUser;
        _syncAvatarFromUser(updatedUser);
        if (!mounted) return;
        setState(() {});
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
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _showAvatarPicker() async {
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.paper.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final username = _user?['username']?.toString() ?? '';
        final letterOption = resolveAvatarOption(username, null);
        final letter = username.isNotEmpty ? username[0].toUpperCase() : '?';
        final letterSelected = _avatarUrl == null &&
            _pendingAvatarBytes == null &&
            _avatarKey == null;

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
                const SizedBox(height: 8),
                ListTile(
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _clearAvatar();
                  },
                  leading: CircleAvatar(
                    backgroundColor: letterOption.background,
                    child: Text(
                      letter,
                      style: GoogleFonts.karla(
                        color: letterOption.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    l10n.useLetterAvatar,
                    style: _valueStyle(context),
                  ),
                  trailing: letterSelected
                      ? Icon(Icons.check, color: context.paper.accent)
                      : null,
                ),
                ListTile(
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickCustomAvatar();
                  },
                  leading: const Icon(Icons.photo_library_outlined),
                  title:
                      Text(l10n.chooseFromGallery, style: _valueStyle(context)),
                ),
                if (_avatarUrl != null)
                  ListTile(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _clearAvatar();
                    },
                    leading:
                        const Icon(Icons.delete_outline, color: Colors.red),
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
    final username = _user?['username']?.toString() ?? '';
    final profile = _publicProfile;
    final challengeCount = profile == null
        ? null
        : (profile.streak?.participatedEditions ?? profile.posts.length);
    final friendCount = profile?.friendCount;
    final streak = profile?.streak;

    return Scaffold(
      backgroundColor: context.paper.bg,
      appBar: paperAppBar(
        context,
        title: username.isNotEmpty ? username : l10n.account,
        subtitle: l10n.account,
        actions: [
          IconButton(
            onPressed: _refreshProfile,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: _isEditing
            ? Form(
                key: _formKey,
                child: _buildContent(
                  l10n,
                  username: username,
                  challengeCount: challengeCount,
                  friendCount: friendCount,
                  streak: streak,
                ),
              )
            : _buildContent(
                l10n,
                username: username,
                challengeCount: challengeCount,
                friendCount: friendCount,
                streak: streak,
              ),
      ),
    );
  }

  Widget _buildContent(
    AppLocalizations l10n, {
    required String username,
    required int? challengeCount,
    required int? friendCount,
    required UserStreak? streak,
  }) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ProfileHeader(
          username: username,
          avatarUrl: _avatarUrl,
          avatarKey: _avatarKey,
          avatarOverride: _pendingAvatarBytes == null
              ? null
              : ClipOval(
                  child: Image.memory(
                    _pendingAvatarBytes!,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                  ),
                ),
          isPrivate: _isPrivate,
          friendCount: friendCount,
          challengeCount: challengeCount,
          onAvatarTap: _showAvatarPicker,
          avatarLoading: _isAvatarLoading,
          action: OutlinedButton.icon(
            onPressed: _isSaving ? null : _startEditing,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l10n.edit),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.paper.ink,
              backgroundColor: context.paper.field.withValues(alpha: 0.7),
              side: BorderSide(color: context.paper.fieldBorder),
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
        ),
        if (streak != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: StreakCard(streak: streak),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildPrivacyCard(l10n),
              if (!_isEmailVerified) ...[
                const SizedBox(height: 16),
                _buildVerificationBanner(l10n),
              ],
              if (_isEditing) ...[
                const SizedBox(height: 16),
                _buildEditCard(l10n),
              ],
              const SizedBox(height: 16),
              _isEditing ? _buildSaveCard(l10n) : _buildLogoutCard(l10n),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyCard(AppLocalizations l10n) {
    return _buildCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.paper.border,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _isPrivate ? Icons.lock_outline : Icons.public,
              color: context.paper.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPrivate ? l10n.privateAccount : l10n.publicAccount,
                  style: _valueStyle(context),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPrivate ? l10n.privateAccountDesc : l10n.publicAccountDesc,
                  style: _mutedStyle(context),
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
                  activeColor: context.paper.accent,
                  onChanged: _togglePrivacy,
                ),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.paper.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.paper.accent.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mark_email_unread_outlined,
                  color: context.paper.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.emailNotVerifiedTitle,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.paper.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.emailNotVerifiedMessage,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: context.paper.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isResendingVerification
                      ? null
                      : _resendVerificationEmail,
                  icon: _isResendingVerification
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text(l10n.resendVerificationEmail),
                  style: FilledButton.styleFrom(
                    backgroundColor: paperAccentStrong,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _refreshProfile,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.refresh),
                style: OutlinedButton.styleFrom(
                    foregroundColor: context.paper.ink),
              ),
            ],
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
                backgroundColor: paperAccentStrong,
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
                foregroundColor: context.paper.ink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: context.paper.fieldBorder),
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
            backgroundColor: paperDanger,
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
        color: context.paper.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.paper.border),
        boxShadow: [
          BoxShadow(
            color: context.paper.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildAvatarChoice({
    required AvatarOption option,
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
          color: isSelected ? context.paper.field : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isSelected ? context.paper.accent : context.paper.fieldBorder,
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
      color: context.paper.ink,
      fontSize: 26,
      letterSpacing: 0.2,
    );
  }

  TextStyle _labelStyle(BuildContext context) {
    return GoogleFonts.karla(
      color: context.paper.inkMuted,
      fontSize: 13,
      letterSpacing: 0.2,
      fontWeight: FontWeight.w600,
    );
  }

  TextStyle _valueStyle(BuildContext context) {
    return GoogleFonts.karla(
      color: context.paper.ink,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
  }

  TextStyle _mutedStyle(BuildContext context) {
    return GoogleFonts.karla(
      color: context.paper.inkMuted,
      fontSize: 14,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: _labelStyle(context),
      filled: true,
      fillColor: context.paper.field,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.paper.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.paper.accent, width: 1.5),
      ),
    );
  }
}
