import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/admin_service.dart';
import '../services/api_exception.dart';

const Color _inkColor = Color(0xFF3B2A21);
const Color _inkMuted = Color(0xFF6A4A3B);
const Color _cardColor = Color(0xFFFFF7E6);
const Color _accentColor = Color(0xFFB85C38);
const Color _runningColor = Color(0xFF195A3B);

/// Page réservée aux comptes ADMIN : création et gestion des défis globaux.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.onUnauthorized});

  final VoidCallback onUnauthorized;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final AdminService _adminService = AdminService();

  List<AdminChallenge> _challenges = [];
  bool _isLoading = true;
  String? _loadError;
  int? _busyChallengeId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final challenges = await _adminService.getChallenges();
      if (!mounted) return;
      setState(() {
        _challenges = challenges;
        _isLoading = false;
        _loadError = null;
      });
    } on UnauthorizedException {
      if (mounted) widget.onUnauthorized();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e is ApiException ? e.message : e.toString();
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Exécute une action admin en gérant les états de chargement et les erreurs.
  Future<void> _run(
    int? challengeId,
    Future<void> Function() action,
  ) async {
    setState(() => _busyChallengeId = challengeId);
    try {
      await action();
      await _load(showLoading: false);
    } on UnauthorizedException {
      if (mounted) widget.onUnauthorized();
    } catch (e) {
      _showError(e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _busyChallengeId = null);
    }
  }

  Future<void> _openEditor({AdminChallenge? challenge}) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showModalBottomSheet<_ChallengeDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ChallengeEditorSheet(challenge: challenge),
    );

    if (result == null || !mounted) return;

    await _run(challenge?.id, () async {
      if (challenge == null) {
        await _adminService.createChallenge(
          title: result.title,
          description: result.description,
          date: result.date,
          type: result.type,
          isActive: result.isActive,
        );
        _showInfo(l10n.adminChallengeCreated);
      } else {
        await _adminService.updateChallenge(
          challenge.id,
          title: result.title,
          description: result.description,
          date: result.date,
          type: result.type,
          isActive: result.isActive,
        );
        _showInfo(l10n.adminChallengeUpdated);
      }
    });
  }

  Future<void> _toggleActive(AdminChallenge challenge, bool value) async {
    await _run(
      challenge.id,
      () => _adminService.updateChallenge(challenge.id, isActive: value),
    );
  }

  Future<void> _delete(AdminChallenge challenge) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminDeleteConfirmTitle),
        content: Text('${challenge.title}\n\n${l10n.adminDeleteConfirmBody}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _run(challenge.id, () async {
      await _adminService.deleteChallenge(challenge.id);
      _showInfo(l10n.adminChallengeDeleted);
    });
  }

  Future<void> _importFromFile() async {
    final l10n = AppLocalizations.of(context)!;
    await _run(null, () async {
      final imported = await _adminService.importChallengesFromFile();
      _showInfo(l10n.adminImported(imported));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.adminChallengesTitle,
          style: GoogleFonts.dmSerifDisplay(color: _inkColor, fontSize: 22),
        ),
        backgroundColor: const Color(0xFFF7EBD1),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: l10n.adminImportFromFile,
            onPressed: _isLoading ? null : _importFromFile,
            icon: const Icon(Icons.file_download_outlined, color: _inkColor),
          ),
        ],
      ),
      body: _buildBody(l10n),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(l10n.adminNewChallenge),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.adminLoadError,
                style: GoogleFonts.karla(color: _inkColor, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _loadError!,
                style: GoogleFonts.karla(color: _inkMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: Text(l10n.feedRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (_challenges.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(showLoading: false),
        child: ListView(
          children: [
            const SizedBox(height: 120),
            const Icon(Icons.emoji_events_outlined, size: 48, color: _inkMuted),
            const SizedBox(height: 12),
            Text(
              l10n.adminNoChallenges,
              textAlign: TextAlign.center,
              style: GoogleFonts.karla(
                color: _inkColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.adminNoChallengesHint,
              textAlign: TextAlign.center,
              style: GoogleFonts.karla(color: _inkMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _challenges.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final challenge = _challenges[i];
          return _ChallengeCard(
            challenge: challenge,
            busy: _busyChallengeId == challenge.id,
            onToggleActive: (value) => _toggleActive(challenge, value),
            onEdit: () => _openEditor(challenge: challenge),
            onDelete: () => _delete(challenge),
          );
        },
      ),
    );
  }
}

String _typeLabel(AppLocalizations l10n, ChallengeType type) => switch (type) {
      ChallengeType.weeklyA => l10n.adminTypeWeeklyA,
      ChallengeType.weeklyB => l10n.adminTypeWeeklyB,
      ChallengeType.special => l10n.adminTypeSpecial,
    };

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.busy,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminChallenge challenge;
  final bool busy;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final (String statusLabel, Color statusColor) = switch (challenge) {
      _ when !challenge.isActive => (l10n.adminStatusDisabled, _inkMuted),
      _ when challenge.isRunning => (l10n.adminStatusRunning, _runningColor),
      _ when challenge.isUpcoming => (l10n.adminStatusUpcoming, _accentColor),
      _ => (l10n.adminStatusFinished, _inkMuted),
    };

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
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  challenge.title,
                  style: GoogleFonts.karla(
                    color: _inkColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(label: statusLabel, color: statusColor),
              const SizedBox(width: 8),
            ],
          ),
          if (challenge.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              challenge.description,
              style: GoogleFonts.karla(color: _inkMuted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '${_typeLabel(l10n, challenge.type)} · ${dateFormat.format(challenge.date)}',
            style: GoogleFonts.karla(color: _inkMuted, fontSize: 12),
          ),
          Text(
            '${l10n.adminEndsOn(dateFormat.format(challenge.endsAt))} · ${l10n.adminPostsCount(challenge.postCount)}',
            style: GoogleFonts.karla(color: _inkMuted, fontSize: 12),
          ),
          Row(
            children: [
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Switch(
                  value: challenge.isActive,
                  activeThumbColor: _accentColor,
                  onChanged: onToggleActive,
                ),
              Expanded(
                child: Text(
                  l10n.adminChallengeActiveLabel,
                  style: GoogleFonts.karla(color: _inkMuted, fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: l10n.edit,
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, color: _accentColor),
              ),
              IconButton(
                tooltip: l10n.delete,
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.karla(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Valeurs saisies dans la feuille d'édition, renvoyées à la page.
class _ChallengeDraft {
  const _ChallengeDraft({
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    required this.isActive,
  });

  final String title;
  final String description;
  final DateTime date;
  final ChallengeType type;
  final bool isActive;
}

class _ChallengeEditorSheet extends StatefulWidget {
  const _ChallengeEditorSheet({this.challenge});

  final AdminChallenge? challenge;

  @override
  State<_ChallengeEditorSheet> createState() => _ChallengeEditorSheetState();
}

class _ChallengeEditorSheetState extends State<_ChallengeEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _date;
  late ChallengeType _type;
  late bool _isActive;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    final challenge = widget.challenge;
    _titleController = TextEditingController(text: challenge?.title ?? '');
    _descriptionController =
        TextEditingController(text: challenge?.description ?? '');
    _date = challenge?.date ?? DateTime.now();
    _type = challenge?.type ?? ChallengeType.weeklyA;
    _isActive = challenge?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      // Un défi peut être daté dans le passé (rattrapage) ou planifié à l'avance.
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (!mounted) return;

    setState(() {
      _date = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _date.hour,
        time?.minute ?? _date.minute,
      );
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = l10n.adminTitleRequired);
      return;
    }

    Navigator.pop(
      context,
      _ChallengeDraft(
        title: title,
        description: _descriptionController.text.trim(),
        date: _date,
        type: _type,
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.challenge != null;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? l10n.adminEditChallenge : l10n.adminNewChallenge,
              style: GoogleFonts.dmSerifDisplay(color: _inkColor, fontSize: 22),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              maxLength: 100,
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
              decoration: InputDecoration(
                labelText: l10n.adminChallengeTitleLabel,
                errorText: _titleError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.adminChallengeDescriptionLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ChallengeType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: l10n.adminChallengeTypeLabel,
                border: const OutlineInputBorder(),
              ),
              items: ChallengeType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(_typeLabel(l10n, type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event, color: _accentColor),
              title: Text(
                l10n.adminChallengeStartLabel,
                style: GoogleFonts.karla(color: _inkMuted, fontSize: 13),
              ),
              subtitle: Text(
                dateFormat.format(_date),
                style: GoogleFonts.karla(
                  color: _inkColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: TextButton(
                onPressed: _pickDate,
                child: Text(l10n.edit),
              ),
            ),
            Text(
              l10n.adminEndsOn(dateFormat.format(_date.add(_type.duration))),
              style: GoogleFonts.karla(color: _inkMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              activeThumbColor: _accentColor,
              title: Text(
                l10n.adminChallengeActiveLabel,
                style: GoogleFonts.karla(
                  color: _inkColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
