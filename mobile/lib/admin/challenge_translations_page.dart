import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/admin_service.dart';
import '../services/api_exception.dart';
import '../widgets/paper.dart';

/// Relecture et correction des traductions d'un défi global, langue par langue.
///
/// Enregistrer une langue la marque « corrigée à la main » : le backend ne
/// l'écrase plus, même si le texte français change. « Revenir à l'auto »
/// redemande une traduction à DeepL.
class ChallengeTranslationsPage extends StatefulWidget {
  const ChallengeTranslationsPage({
    super.key,
    required this.challenge,
    required this.onUnauthorized,
    this.adminService,
  });

  final AdminChallenge challenge;
  final VoidCallback onUnauthorized;
  final AdminService? adminService;

  @override
  State<ChallengeTranslationsPage> createState() =>
      _ChallengeTranslationsPageState();
}

class _ChallengeTranslationsPageState extends State<ChallengeTranslationsPage> {
  late final AdminService _adminService = widget.adminService ?? AdminService();
  late AdminChallenge _challenge = widget.challenge;
  final Map<String, TextEditingController> _titles = {};
  final Map<String, TextEditingController> _descriptions = {};
  final Map<String, String?> _titleErrors = {};
  String? _busyLocale;

  @override
  void initState() {
    super.initState();
    for (final locale in challengeTranslationLocales.keys) {
      _titles[locale] = TextEditingController();
      _descriptions[locale] = TextEditingController();
      _syncControllers(locale);
    }
  }

  @override
  void dispose() {
    for (final controller in [..._titles.values, ..._descriptions.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllers(String locale) {
    final translation = _challenge.translations[locale];
    _titles[locale]!.text = translation?.title ?? '';
    _descriptions[locale]!.text = translation?.description ?? '';
  }

  Future<void> _run(
    String locale,
    Future<AdminChallenge> Function() action,
    String successMessage,
  ) async {
    setState(() => _busyLocale = locale);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _challenge = updated;
        _syncControllers(locale);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } on UnauthorizedException {
      if (mounted) widget.onUnauthorized();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: paperDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyLocale = null);
    }
  }

  Future<void> _save(String locale) async {
    final l10n = AppLocalizations.of(context)!;
    final title = _titles[locale]!.text.trim();
    if (title.isEmpty) {
      setState(() => _titleErrors[locale] = l10n.adminTitleRequired);
      return;
    }
    FocusScope.of(context).unfocus();
    await _run(
      locale,
      () => _adminService.setChallengeTranslation(
        _challenge.id,
        locale,
        title: title,
        description: _descriptions[locale]!.text.trim(),
      ),
      l10n.adminTranslationSaved,
    );
  }

  Future<void> _reset(String locale) async {
    final l10n = AppLocalizations.of(context)!;
    await _run(
      locale,
      () => _adminService.resetChallengeTranslation(_challenge.id, locale),
      l10n.adminTranslationResetDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.paper.bg,
      appBar: AppBar(
        title: Text(
          l10n.adminTranslationsTitle,
          style:
              GoogleFonts.dmSerifDisplay(color: context.paper.ink, fontSize: 22),
        ),
        backgroundColor: context.paper.bg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            l10n.adminTranslationHint,
            style: GoogleFonts.karla(color: context.paper.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _Section(
            header: l10n.adminTranslationOriginal,
            children: [
              Text(
                _challenge.title,
                style: GoogleFonts.karla(
                  color: context.paper.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_challenge.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _challenge.description,
                  style: GoogleFonts.karla(
                      color: context.paper.inkMuted, fontSize: 14),
                ),
              ],
            ],
          ),
          for (final entry in challengeTranslationLocales.entries) ...[
            const SizedBox(height: 12),
            _buildLocaleSection(l10n, entry.key, entry.value),
          ],
        ],
      ),
    );
  }

  Widget _buildLocaleSection(
    AppLocalizations l10n,
    String locale,
    String languageName,
  ) {
    final translation = _challenge.translations[locale];
    final busy = _busyLocale == locale;

    final (String status, Color statusColor) = switch (translation) {
      null => (l10n.adminTranslationMissing, context.paper.danger),
      AdminChallengeTranslation(manual: true) => (
          l10n.adminTranslationManual,
          context.paper.accent,
        ),
      _ => (l10n.adminTranslationAuto, context.paper.success),
    };

    return _Section(
      header: languageName,
      status: status,
      statusColor: statusColor,
      children: [
        TextField(
          controller: _titles[locale],
          maxLength: 100,
          enabled: !busy,
          onChanged: (_) {
            if (_titleErrors[locale] != null) {
              setState(() => _titleErrors[locale] = null);
            }
          },
          decoration: InputDecoration(
            labelText: l10n.adminChallengeTitleLabel,
            errorText: _titleErrors[locale],
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _descriptions[locale],
          maxLength: 500,
          maxLines: 3,
          minLines: 1,
          enabled: !busy,
          decoration: InputDecoration(
            labelText: l10n.adminChallengeDescriptionLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        // Wrap : les libellés longs passent à la ligne sur petit écran.
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (translation?.manual == true || translation == null)
              TextButton(
                onPressed: busy ? null : () => _reset(locale),
                child: Text(l10n.adminTranslationResetAuto),
              ),
            ElevatedButton(
              onPressed: busy ? null : () => _save(locale),
              style: ElevatedButton.styleFrom(
                backgroundColor: paperAccentStrong,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.save),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.header,
    required this.children,
    this.status,
    this.statusColor,
  });

  final String header;
  final String? status;
  final Color? statusColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: paperCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  header,
                  style: paperLabel(context, fontSize: 13),
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 8),
                // Statut en texte : l'état ne repose jamais sur la seule couleur.
                Flexible(
                  flex: 2,
                  child: Text(
                    status!,
                    textAlign: TextAlign.end,
                    style:
                        paperLabel(context, fontSize: 12, color: statusColor),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
