import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import '../services/api_exception.dart';
import '../widgets/paper.dart';

/// Onglet « Défis » d'un groupe : liste les défis du groupe et permet à
/// n'importe quel membre d'en créer un (fenêtre maintenant → endsAt).
class GroupChallengesTab extends StatefulWidget {
  final int conversationId;

  const GroupChallengesTab({super.key, required this.conversationId});

  @override
  State<GroupChallengesTab> createState() => _GroupChallengesTabState();
}

class _GroupChallengesTabState extends State<GroupChallengesTab> {
  final ChatService _chatService = ChatService();
  List<dynamic> _challenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _chatService.getGroupChallenges(widget.conversationId);
      if (mounted) {
        setState(() {
          _challenges = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e is ApiException ? e.message : 'Erreur de chargement');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: paperDanger),
    );
  }

  bool _isActive(Map<String, dynamic> c) {
    final endsAt = DateTime.tryParse(c['endsAt']?.toString() ?? '')?.toLocal();
    return endsAt != null && endsAt.isAfter(DateTime.now());
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _CreateChallengeDialog(conversationId: widget.conversationId),
    );

    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paperBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: paperAccent))
          : RefreshIndicator(
              onRefresh: _load,
              color: paperAccent,
              child: _challenges.isEmpty
                  ? const PaperEmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: 'Aucun défi',
                      message: 'Crée le premier défi du groupe !',
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: _challenges.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final c = _challenges[i] as Map<String, dynamic>;
                        return _ChallengeCard(
                          challenge: c,
                          isActive: _isActive(c),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: paperAccentStrong,
        foregroundColor: Colors.white,
        tooltip: 'Créer un défi',
        icon: const Icon(Icons.add),
        label: Text('Défi', style: paperValue(color: Colors.white)),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge, required this.isActive});

  final Map<String, dynamic> challenge;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final endsAt =
        DateTime.tryParse(challenge['endsAt']?.toString() ?? '')?.toLocal();
    final description = challenge['description']?.toString() ?? '';
    final status = isActive && endsAt != null
        ? 'Se termine le ${DateFormat('dd/MM à HH:mm').format(endsAt)}'
        : 'Terminé';

    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: paperCardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: PaperIconChip(
                icon: isActive ? Icons.emoji_events : Icons.history,
                color: isActive ? paperAccentStrong : paperInkMuted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge['title']?.toString() ?? '',
                    style: paperValue(fontSize: 16),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(description, style: paperMuted(fontSize: 14)),
                  ],
                  const SizedBox(height: 8),
                  // Statut en texte : l'état ne repose jamais sur la seule couleur.
                  Text(
                    status,
                    style: paperLabel(
                      fontSize: 12,
                      color: isActive ? paperAccentStrong : paperInkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateful : les contrôleurs de texte vivent exactement le temps du dialogue.
class _CreateChallengeDialog extends StatefulWidget {
  const _CreateChallengeDialog({required this.conversationId});

  final int conversationId;

  @override
  State<_CreateChallengeDialog> createState() => _CreateChallengeDialogState();
}

class _CreateChallengeDialogState extends State<_CreateChallengeDialog> {
  final ChatService _chatService = ChatService();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  // Défaut : fin dans 3 jours.
  DateTime _endsAt = DateTime.now().add(const Duration(days: 3));
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: paperDanger),
    );
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endsAt),
    );
    if (!mounted) return;

    setState(() {
      _endsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _endsAt.hour,
        time?.minute ?? _endsAt.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Le titre est obligatoire');
      return;
    }
    if (!_endsAt.isAfter(DateTime.now())) {
      _showError('La date de fin doit être dans le futur');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _chatService.createGroupChallenge(
        widget.conversationId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        endsAt: _endsAt,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e is ApiException ? e.message : 'Erreur');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: paperCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Nouveau défi', style: paperTitle(fontSize: 21)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              maxLength: 100,
              style: paperValue(),
              decoration: paperInputDecoration(label: 'Titre'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLength: 500,
              maxLines: 2,
              style: paperValue(fontSize: 14),
              decoration:
                  paperInputDecoration(label: 'Description (optionnel)'),
            ),
            const SizedBox(height: 16),
            Text('Fin du défi', style: paperLabel()),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickEndDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(DateFormat('dd/MM/yyyy à HH:mm').format(_endsAt)),
              style: OutlinedButton.styleFrom(
                foregroundColor: paperInk,
                side: const BorderSide(color: Color(0xFFE7D3B5)),
                minimumSize: const Size(double.infinity, 48),
                alignment: Alignment.centerLeft,
                textStyle: paperValue(fontSize: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: paperInk),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: paperAccentStrong,
            foregroundColor: Colors.white,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Créer'),
        ),
      ],
    );
  }
}
