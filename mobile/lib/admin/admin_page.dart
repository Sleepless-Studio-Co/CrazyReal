import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/admin_service.dart';
import '../services/api_exception.dart';
import '../widgets/sticker_pop.dart';

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
      SnackBar(content: Text(message), backgroundColor: popCoral),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
          durationHours: result.durationHours,
          customEndsAt: result.customEndsAt,
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
          durationHours: result.durationHours,
          customEndsAt: result.customEndsAt,
          clearCustomEndsAt: result.customEndsAt == null,
          clearDuration: result.durationHours == null,
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
    final confirmed = await popConfirm(
      context,
      title: l10n.adminDeleteConfirmTitle,
      message: '${challenge.title}\n\n${l10n.adminDeleteConfirmBody}',
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      danger: true,
    );
    if (!confirmed || !mounted) return;

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
      appBar: popAppBar(
        title: l10n.adminChallengesTitle,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PopIconButton(
              tooltip: l10n.adminImportFromFile,
              onPressed: _isLoading ? null : _importFromFile,
              icon: Icons.file_download_outlined,
              size: 44,
            ),
          ),
        ],
      ),
      body: _buildBody(l10n),
      floatingActionButton: PopButton(
        onPressed: () => _openEditor(),
        icon: Icons.add,
        label: l10n.adminNewChallenge,
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return PopEmptyState(
        mascot: PopMascotMood.crying,
        title: l10n.adminLoadError,
        message: _loadError,
        action: PopButton(
          onPressed: _load,
          icon: Icons.refresh,
          label: l10n.feedRetry,
        ),
      );
    }

    if (_challenges.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(showLoading: false),
        child: PopEmptyState(
          mascot: PopMascotMood.confused,
          title: l10n.adminNoChallenges,
          message: l10n.adminNoChallengesHint,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _challenges.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
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
      _ when !challenge.isActive => (l10n.adminStatusDisabled, popBg),
      _ when challenge.isRunning => (l10n.adminStatusRunning, popGreen),
      _ when challenge.isUpcoming => (l10n.adminStatusUpcoming, popYellow),
      _ => (l10n.adminStatusFinished, popBg),
    };

    return Container(
      decoration: popCardDecoration(radius: 18, shadow: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(challenge.title, style: popTitle(fontSize: 17)),
              ),
              const SizedBox(width: 8),
              PopSticker(
                label: statusLabel,
                color: statusColor,
                angle: 0.04,
                fontSize: 11,
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (challenge.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(challenge.description, style: popMuted(fontSize: 14)),
          ],
          const SizedBox(height: 10),
          Text(
            '${_typeLabel(l10n, challenge.type)} · ${dateFormat.format(challenge.date)}',
            style: popMuted(fontSize: 12),
          ),
          Text(
            '${l10n.adminEndsOn(dateFormat.format(challenge.endsAt))} · ${l10n.adminPostsCount(challenge.postCount)}',
            style: popMuted(fontSize: 12),
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
                  onChanged: onToggleActive,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.adminChallengeActiveLabel,
                  style: popValue(fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: l10n.edit,
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, color: popInk),
              ),
              IconButton(
                tooltip: l10n.delete,
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline, color: popDanger),
              ),
            ],
          ),
        ],
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
    required this.durationHours,
    required this.customEndsAt,
    required this.isActive,
  });

  final String title;
  final String description;
  final DateTime date;
  final ChallengeType type;
  final int? durationHours;
  final DateTime? customEndsAt;
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
  late bool _customDuration;
  late DateTime? _customEndsAt;
  late bool _isActive;
  String? _titleError;
  String? _durationError;

  @override
  void initState() {
    super.initState();
    final challenge = widget.challenge;
    _titleController = TextEditingController(text: challenge?.title ?? '');
    _descriptionController =
        TextEditingController(text: challenge?.description ?? '');
    _date = challenge?.date ?? DateTime.now();
    _type = challenge?.type ?? ChallengeType.weeklyA;
    _customDuration =
        challenge?.durationHours != null || challenge?.customEndsAt != null;
    _customEndsAt = challenge?.customEndsAt;
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

  Future<void> _pickCustomEndDate() async {
    final initial = _customEndsAt ?? _date.add(const Duration(days: 3));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _date,
      lastDate: _date.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;

    setState(() {
      _customEndsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? initial.hour,
        time?.minute ?? initial.minute,
      );
      _durationError = null;
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = l10n.adminTitleRequired);
      return;
    }

    if (_customDuration &&
        (_customEndsAt == null || !_customEndsAt!.isAfter(_date))) {
      setState(() => _durationError = l10n.adminEndDateRequired);
      return;
    }

    Navigator.pop(
      context,
      _ChallengeDraft(
        title: title,
        description: _descriptionController.text.trim(),
        date: _date,
        type: _type,
        durationHours: null,
        customEndsAt: _customDuration ? _customEndsAt : null,
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
              style: popTitle(),
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
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.adminChallengeDescriptionLabel,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ChallengeType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: l10n.adminChallengeTypeLabel,
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _customDuration,
              title: Text(l10n.adminCustomDuration, style: popValue()),
              subtitle: Text(
                _customDuration
                    ? l10n.adminCustomDurationHint
                    : l10n.adminDurationFromType,
                style: popMuted(fontSize: 12),
              ),
              onChanged: (value) => setState(() => _customDuration = value),
            ),
            if (_customDuration)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const PopIconChip(icon: Icons.timer_outlined),
                title: Text(l10n.adminCustomEndDate, style: popMuted()),
                subtitle: Text(
                  _customEndsAt == null
                      ? l10n.adminEndDateRequired
                      : dateFormat.format(_customEndsAt!),
                  style: popValue(
                    color: _durationError == null ? popInk : popDanger,
                  ),
                ),
                trailing: TextButton(
                  onPressed: _pickCustomEndDate,
                  child: Text(l10n.edit),
                ),
              ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const PopIconChip(icon: Icons.event),
              title: Text(l10n.adminChallengeStartLabel, style: popMuted()),
              subtitle: Text(dateFormat.format(_date), style: popValue()),
              trailing: TextButton(
                onPressed: _pickDate,
                child: Text(l10n.edit),
              ),
            ),
            Text(
              l10n.adminEndsOn(
                dateFormat.format(
                  _date.add(
                    _customDuration && _customEndsAt != null
                        ? _customEndsAt!.difference(_date)
                        : _type.duration,
                  ),
                ),
              ),
              style: popMuted(fontSize: 12),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              title: Text(l10n.adminChallengeActiveLabel, style: popValue()),
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PopButton(
                  onPressed: () => Navigator.pop(context),
                  label: l10n.cancel,
                  color: popCard,
                  foreground: popInk,
                  dense: true,
                ),
                const SizedBox(width: 12),
                PopButton(
                  onPressed: _submit,
                  label: l10n.save,
                  dense: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
