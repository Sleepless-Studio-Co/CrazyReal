import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth_service.dart';
import 'l10n/app_localizations.dart';
import 'locale_notifier.dart';
import 'services/api_exception.dart';

const Color _inkColor = Color(0xFF3B2A21);
const Color _inkMuted = Color(0xFF6A4A3B);
const Color _cardColor = Color(0xFFFFF7E6);
const Color _accentColor = Color(0xFFB85C38);
const Color _dangerColor = Color(0xFFB54132);

class SettingPage extends StatefulWidget {
  const SettingPage({
    super.key,
    required this.onLoggedOut,
    required this.onUnauthorized,
  });

  final VoidCallback onLoggedOut;
  final VoidCallback onUnauthorized;

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final _authService = AuthService();
  bool _isPrivate = false;
  bool _isPrivacySaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
  }

  Future<void> _loadPrivacy() async {
    final user = await _authService.getUser();
    if (!mounted) return;
    setState(() {
      _isPrivate = user?['isPrivate'] == true;
    });
  }

  Future<void> _togglePrivacy(bool value) async {
    setState(() => _isPrivacySaving = true);
    try {
      final result = await _authService.updatePrivacy(value);
      final u = result['user'];
      if (mounted) {
        setState(() {
          _isPrivate = u is Map ? (u['isPrivate'] == true) : value;
        });
      }
    } on UnauthorizedException {
      if (mounted) widget.onUnauthorized();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isPrivacySaving = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (!await confirmAccountDeletion(context) || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _authService.deleteAccount();
      if (mounted) widget.onLoggedOut();
    } on UnauthorizedException {
      if (mounted) widget.onUnauthorized();
    } catch (e) {
      _showError(e.toString());
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _showLanguagePicker() async {
    final l10n = AppLocalizations.of(context)!;
    final current = appLocale.value.languageCode;
    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.selectLanguage),
        children: [
          _LangOption(code: 'en', label: l10n.english, current: current),
          _LangOption(code: 'fr', label: l10n.french, current: current),
        ],
      ),
    );
  }

  void _showHelp() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.helpCenter),
        content: Text(l10n.helpInfo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.comingSoon)),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langLabel = appLocale.value.languageCode == 'fr' ? l10n.french : l10n.english;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: GoogleFonts.dmSerifDisplay(color: _inkColor, fontSize: 22),
        ),
        backgroundColor: const Color(0xFFF7EBD1),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionHeader(l10n.account),
          _SettingCard(children: [
            _SwitchTile(
              icon: _isPrivate ? Icons.lock_outline : Icons.public,
              title: _isPrivate ? l10n.privateAccount : l10n.publicAccount,
              subtitle: _isPrivate ? l10n.privateAccountDesc : l10n.publicAccountDesc,
              value: _isPrivate,
              loading: _isPrivacySaving,
              onChanged: _togglePrivacy,
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(l10n.privacy),
          _SettingCard(children: [
            _NavTile(
              icon: Icons.block,
              title: l10n.blockedUsers,
              onTap: _showComingSoon,
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(l10n.accessibility),
          _SettingCard(children: [
            _NavTile(
              icon: Icons.language,
              title: l10n.language,
              subtitle: langLabel,
              onTap: _showLanguagePicker,
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(l10n.helpCenter),
          _SettingCard(children: [
            _NavTile(
              icon: Icons.help_outline,
              title: l10n.helpCenter,
              onTap: _showHelp,
            ),
          ]),
          const SizedBox(height: 24),
          _SettingCard(children: [
            _NavTile(
              icon: Icons.delete_forever_outlined,
              title: l10n.deleteAccount,
              iconColor: _dangerColor,
              titleColor: _dangerColor,
              loading: _isDeleting,
              onTap: _deleteAccount,
            ),
          ]),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.code,
    required this.label,
    required this.current,
  });

  final String code;
  final String label;
  final String current;

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: () async {
        Navigator.pop(context);
        appLocale.value = Locale(code, '');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_locale', code);
      },
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: current == code
                ? const Icon(Icons.check, size: 18, color: _accentColor)
                : null,
          ),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.karla(fontSize: 15, color: _inkColor)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.karla(
          color: _inkMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(children: children),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    Widget trailing;
    if (loading) {
      trailing = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      trailing = const Icon(Icons.chevron_right, color: _inkMuted, size: 20);
    }

    return ListTile(
      onTap: loading ? null : onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0DFC2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? _accentColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.karla(
          color: titleColor ?? _inkColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: GoogleFonts.karla(color: _inkMuted, fontSize: 13),
            )
          : null,
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0DFC2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _accentColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.karla(
          color: _inkColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: GoogleFonts.karla(color: _inkMuted, fontSize: 13),
            )
          : null,
      trailing: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: value,
              activeThumbColor: _accentColor,
              onChanged: onChanged,
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

/// Asks the user to type the confirmation word before deleting the account.
/// Returns true only when the typed word matches — the destructive action
/// stays disabled until then.
Future<bool> confirmAccountDeletion(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
  return confirmed == true;
}

/// Stateful so the text controller lives exactly as long as the dialog does.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final word = l10n.deleteAccountConfirmWord;

    return AlertDialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        l10n.deleteAccountConfirmTitle,
        style: GoogleFonts.dmSerifDisplay(color: _inkColor, fontSize: 21),
      ),
      // Scrollable so the dialog survives large text scales and the keyboard.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.deleteAccountConfirmBody,
              style: GoogleFonts.karla(color: _inkMuted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.deleteAccountConfirmPrompt(word),
              style: GoogleFonts.karla(
                color: _inkColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.karla(
                color: _inkColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: l10n.deleteAccountConfirmHint,
                hintText: word,
                labelStyle: GoogleFonts.karla(color: _inkMuted, fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE7D3B5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _dangerColor, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: _inkColor),
          child: Text(l10n.cancel),
        ),
        // Stays disabled — and announced as such — until the word matches.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (_, value, __) {
            final matches =
                value.text.trim().toUpperCase() == word.toUpperCase();
            return TextButton(
              onPressed: matches ? () => Navigator.pop(context, true) : null,
              style: TextButton.styleFrom(foregroundColor: _dangerColor),
              child: Text(l10n.deleteAccount),
            );
          },
        ),
      ],
    );
  }
}
