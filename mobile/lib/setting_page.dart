import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin/admin_page.dart';
import 'auth/auth_service.dart';
import 'l10n/app_localizations.dart';
import 'locale_notifier.dart';
import 'services/api_exception.dart';
import 'widgets/sticker_pop.dart';

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
  bool _isAdmin = false;
  bool _isPrivacySaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    _applyUser(await _authService.getUser());

    // Le rôle n'est renvoyé que par /auth/me : on rafraîchit le profil pour
    // savoir si l'entrée d'administration doit apparaître.
    try {
      _applyUser(await _authService.fetchProfile());
    } catch (_) {
      // Hors ligne : on garde ce que le cache local nous a donné.
    }
  }

  void _applyUser(Map<String, dynamic>? user) {
    if (user == null || !mounted) return;
    setState(() {
      _isPrivate = user['isPrivate'] == true;
      _isAdmin = user['role'] == 'ADMIN';
    });
  }

  void _openAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminPage(onUnauthorized: widget.onUnauthorized),
      ),
    );
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
    if (mounted) setState(() {});
  }

  void _showHelp() {
    final l10n = AppLocalizations.of(context)!;
    popInfo(context, title: l10n.helpCenter, message: l10n.helpInfo);
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
      SnackBar(content: Text(message), backgroundColor: popCoral),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langLabel = appLocale.value.languageCode == 'fr' ? l10n.french : l10n.english;

    return Scaffold(
      appBar: popAppBar(title: l10n.settings),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_isAdmin) ...[
            _SectionHeader(l10n.administration),
            _SettingCard(children: [
              _NavTile(
                icon: Icons.shield_outlined,
                title: l10n.administration,
                subtitle: l10n.administrationDesc,
                onTap: _openAdmin,
              ),
            ]),
            const SizedBox(height: 16),
          ],
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
              iconColor: popDanger,
              titleColor: popDanger,
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
                ? const Icon(Icons.check, size: 18, color: popPurple)
                : null,
          ),
          const SizedBox(width: 8),
          Text(label, style: popValue()),
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
      child: Text(title.toUpperCase(), style: popLabel()),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: popCardDecoration(radius: 18, shadow: 4),
      clipBehavior: Clip.antiAlias,
      // Transparent material so the tiles' ink shows above the white card.
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: children),
      ),
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
      trailing = const Icon(Icons.chevron_right, color: popInk, size: 22);
    }

    return ListTile(
      onTap: loading ? null : onTap,
      leading: PopIconChip(icon: icon, color: iconColor ?? popInk),
      title: Text(
        title,
        style: popValue(color: titleColor ?? popInk),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: popMuted())
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
      leading: PopIconChip(icon: icon),
      title: Text(title, style: popValue()),
      subtitle: subtitle != null
          ? Text(subtitle!, style: popMuted())
          : null,
      trailing: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(value: value, onChanged: onChanged),
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
      title: Text(l10n.deleteAccountConfirmTitle),
      // Scrollable so the dialog survives large text scales and the keyboard.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.deleteAccountConfirmBody,
              style: popBody(fontSize: 14, color: popInkMuted),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.deleteAccountConfirmPrompt(word),
              style: popValue(fontSize: 14),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              style: popValue(),
              decoration: InputDecoration(
                labelText: l10n.deleteAccountConfirmHint,
                hintText: word,
                floatingLabelStyle: popValue(color: popDanger),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: popDanger, width: popStroke),
                ),
              ),
            ),
            const SizedBox(height: 22),
            // Full-width buttons: the long destructive label does not fit
            // next to « Annuler » in the dialog's action bar.
            // Stays disabled — and announced as such — until the word matches.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, value, __) {
                final matches =
                    value.text.trim().toUpperCase() == word.toUpperCase();
                return PopButton(
                  onPressed:
                      matches ? () => Navigator.pop(context, true) : null,
                  label: l10n.deleteAccount,
                  color: popCoral,
                  foreground: popInk,
                  expand: true,
                );
              },
            ),
            const SizedBox(height: 12),
            PopButton(
              onPressed: () => Navigator.pop(context, false),
              label: l10n.cancel,
              color: popCard,
              foreground: popInk,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}
