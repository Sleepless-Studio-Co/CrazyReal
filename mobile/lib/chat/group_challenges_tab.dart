import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import '../services/api_exception.dart';

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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  bool _isActive(Map<String, dynamic> c) {
    final endsAt = DateTime.tryParse(c['endsAt']?.toString() ?? '')?.toLocal();
    return endsAt != null && endsAt.isAfter(DateTime.now());
  }

  Future<void> _openCreateDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    // Défaut : fin dans 3 jours.
    DateTime endsAt = DateTime.now().add(const Duration(days: 3));

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nouveau défi'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      maxLength: 100,
                      decoration: const InputDecoration(labelText: 'Titre'),
                    ),
                    TextField(
                      controller: descController,
                      maxLength: 500,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Description (optionnel)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Text('Fin le')),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: endsAt,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date == null) return;
                            final time = await showTimePicker(
                              // ignore: use_build_context_synchronously
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(endsAt),
                            );
                            setDialogState(() {
                              endsAt = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time?.hour ?? endsAt.hour,
                                time?.minute ?? endsAt.minute,
                              );
                            });
                          },
                          child: Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(endsAt),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      _showError('Le titre est obligatoire');
                      return;
                    }
                    if (!endsAt.isAfter(DateTime.now())) {
                      _showError('La date de fin doit être dans le futur');
                      return;
                    }
                    try {
                      await _chatService.createGroupChallenge(
                        widget.conversationId,
                        title: titleController.text.trim(),
                        description: descController.text.trim(),
                        endsAt: endsAt,
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (e) {
                      _showError(e is ApiException ? e.message : 'Erreur');
                    }
                  },
                  child: const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _challenges.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun défi. Créez-en un !',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _challenges.length,
                    itemBuilder: (_, i) {
                      final c = _challenges[i] as Map<String, dynamic>;
                      final active = _isActive(c);
                      final endsAt =
                          DateTime.tryParse(c['endsAt']?.toString() ?? '')
                              ?.toLocal();
                      return ListTile(
                        leading: Icon(
                          active ? Icons.emoji_events : Icons.history,
                          color: active ? const Color(0xFF195A3B) : Colors.grey,
                        ),
                        title: Text(c['title']?.toString() ?? ''),
                        subtitle: Text(
                          [
                            if ((c['description']?.toString() ?? '').isNotEmpty)
                              c['description'].toString(),
                            if (endsAt != null)
                              active
                                  ? 'Se termine le ${DateFormat('dd/MM HH:mm').format(endsAt)}'
                                  : 'Terminé',
                          ].join('\n'),
                        ),
                        isThreeLine:
                            (c['description']?.toString() ?? '').isNotEmpty,
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: const Color(0xFF195A3B),
        icon: const Icon(Icons.add),
        label: const Text('Défi'),
      ),
    );
  }
}
