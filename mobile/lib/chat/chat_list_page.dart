import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../services/chat_service.dart';
import '../services/chat_socket_service.dart';
import '../services/api_exception.dart';
import '../widgets/feed_avatar.dart';
import '../widgets/paper.dart';
import 'chat_room_page.dart';
import 'create_group_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final ChatSocketService _chatSocket = ChatSocketService();

  List<dynamic> _conversations = [];
  bool _isLoading = true;

  int? _currentUserId;

  // Conversation actuellement ouverte (pour ne pas la marquer non-lue).
  int? _openConversationId;

  // État temps réel, indexé par conversationId.
  final Map<int, int> _unread = {};
  final Map<int, String> _lastPreview = {};

  StreamSubscription<Map<String, dynamic>>? _messageSub;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadConversations();
    _chatSocket.connect();
    _messageSub = _chatSocket.messages.listen(_onSocketMessage);
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getUser();
    if (mounted && user != null) {
      setState(() => _currentUserId = user['id'] as int?);
    }
  }

  void _onSocketMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    final convId = msg['conversationId'] as int?;
    if (convId == null) return;

    // Une conversation inconnue de la liste (nouvellement créée) : on recharge.
    final idx = _conversations.indexWhere((c) => c['id'] == convId);
    if (idx == -1) {
      _loadConversations();
      return;
    }

    final senderId = (msg['sender'] as Map?)?['id'] as int?;
    final isOwn = senderId != null && senderId == _currentUserId;

    setState(() {
      _lastPreview[convId] = (msg['content'] as String?) ?? '';
      // Pas de badge pour ses propres messages ni pour la conversation ouverte.
      if (!isOwn && convId != _openConversationId) {
        _unread[convId] = (_unread[convId] ?? 0) + 1;
      }
      // Remonter la conversation en tête de liste.
      final conv = _conversations.removeAt(idx);
      _conversations.insert(0, conv);
    });
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final convos = await _chatService.getConversations();
      if (mounted) {
        setState(() {
          _conversations = convos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final message = e is ApiException ? e.message : 'Erreur lors du chargement des discussions';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: paperDanger),
        );
      }
    }
  }

  Future<void> _openConversation(dynamic conv, String name, bool isGroup) async {
    final convId = conv['id'] as int;
    setState(() {
      _openConversationId = convId;
      _unread.remove(convId);
    });
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomPage(
          conversationId: convId,
          conversationName: name,
          isGroup: isGroup,
        ),
      ),
    );
    _openConversationId = null;
  }

  Future<void> _openCreateGroup() async {
    // CreateGroupPage gère elle-même le cas « aucun ami » (elle charge la
    // liste et se referme), inutile de la dupliquer ici.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateGroupPage()),
    );
    if (mounted) _loadConversations();
  }

  Future<void> _leaveGroup(int conversationId) async {
    final confirmed = await paperConfirm(
      context,
      title: 'Quitter le groupe',
      message: 'Veux-tu vraiment quitter ce groupe ?',
      confirmLabel: 'Quitter',
      cancelLabel: 'Annuler',
      danger: true,
    );

    if (!confirmed) return;

    try {
      await _chatService.leaveGroup(conversationId);
      _loadConversations();
    } catch (e) {
      if (mounted) {
        final message = e is ApiException ? e.message : 'Erreur lors de la sortie du groupe';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: paperDanger),
        );
      }
    }
  }

  /// Nom affiché : celui du groupe, sinon le pseudo de l'autre participant.
  Map<String, dynamic>? _otherParticipant(dynamic conv) {
    final participants = conv['participants'] as List? ?? const [];
    for (final p in participants) {
      final user = (p as Map)['user'] as Map<String, dynamic>?;
      if (user != null && user['id'] != _currentUserId) return user;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: paperBg,
      appBar: paperAppBar(title: l10n.messages),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: paperAccent))
          : RefreshIndicator(
              onRefresh: _loadConversations,
              color: paperAccent,
              child: _conversations.isEmpty
                  ? const PaperEmptyState(
                      icon: Icons.forum_outlined,
                      title: 'Aucune discussion pour le moment.',
                      message:
                          'Crée un groupe avec le bouton ci-dessous pour lancer une conversation.',
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final conv = _conversations[index];
                        final convId = conv['id'] as int;
                        final isGroup = conv['isGroup'] == true;
                        final other = isGroup ? null : _otherParticipant(conv);
                        final name = (conv['name'] as String?) ??
                            other?['username']?.toString() ??
                            'Discussion privée';

                        final participants = conv['participants'] as List;
                        final preview = _lastPreview[convId];
                        final unread = _unread[convId] ?? 0;

                        return _ConversationCard(
                          name: name,
                          isGroup: isGroup,
                          other: other,
                          subtitle:
                              preview ?? '${participants.length} membre(s)',
                          unread: unread,
                          onTap: () => _openConversation(conv, name, isGroup),
                          onLeave:
                              isGroup ? () => _leaveGroup(convId) : null,
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateGroup,
        backgroundColor: paperAccentStrong,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add_outlined),
        label: Text(l10n.newGroup, style: paperValue(color: Colors.white)),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.name,
    required this.isGroup,
    required this.other,
    required this.subtitle,
    required this.unread,
    required this.onTap,
    this.onLeave,
  });

  final String name;
  final bool isGroup;
  final Map<String, dynamic>? other;
  final String subtitle;
  final int unread;
  final VoidCallback onTap;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;

    return Container(
      decoration: paperCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: isGroup
                      ? Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: paperChip,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.groups_outlined,
                              color: paperAccentStrong),
                        )
                      : FeedAvatar(
                          username: other?['username']?.toString() ?? name,
                          avatarUrl: other?['avatarUrl']?.toString(),
                          avatarKey: other?['avatarKey']?.toString(),
                          size: 48,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: paperValue(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          // Unread threads are bolder *and* badged — colour is
                          // never the only signal.
                          style: hasUnread
                              ? paperValue(fontSize: 13, color: paperInk)
                              : paperMuted(),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(width: 8),
                  Semantics(
                    label: '$unread message(s) non lu(s)',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      constraints: const BoxConstraints(minWidth: 24),
                      decoration: BoxDecoration(
                        color: paperAccentStrong,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          '$unread',
                          textAlign: TextAlign.center,
                          style: paperValue(fontSize: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
                if (onLeave != null)
                  IconButton(
                    icon: const Icon(Icons.logout),
                    color: paperDanger,
                    tooltip: 'Quitter le groupe $name',
                    onPressed: onLeave,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
