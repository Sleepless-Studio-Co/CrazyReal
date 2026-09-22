import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../services/chat_service.dart';
import '../services/chat_socket_service.dart';
import '../services/api_exception.dart';
import '../widgets/feed_avatar.dart';
import '../widgets/paper.dart';
import 'group_members_page.dart';
import 'group_challenges_tab.dart';
import 'group_feed_tab.dart';

class ChatRoomPage extends StatefulWidget {
  final int conversationId;
  final String conversationName;
  final bool isGroup;

  const ChatRoomPage({
    super.key,
    required this.conversationId,
    required this.conversationName,
    this.isGroup = false,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Messages list — each entry is a Map<String, dynamic> with fields:
  //   id (int?), tempId (String?), content, sender {id, username},
  //   createdAt, pending (bool), failed (bool)
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _messagesLoaded = false;
  bool _socketWasConnected = false;

  int? _currentUserId;
  String _currentUsername = '';

  final ChatSocketService _chatSocket = ChatSocketService();
  StreamSubscription<Map<String, dynamic>>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  StreamSubscription<bool>? _connectionSub;

  final Map<int, String> _typingUsers = {};
  final Map<int, Timer> _typingTimeouts = {};
  Timer? _stopTypingDebounce;
  bool _isTyping = false;

  // Filet de sécurité : si le websocket meurt (ping timeout/transport close sur
  // mobile), ce poll garantit que les nouveaux messages apparaissent en quelques
  // secondes au lieu d'attendre la reconnexion. Quand le socket est vivant, il
  // ne récupère rien (0 message) — le live reste instantané.
  Timer? _backupPollTimer;
  static const Duration _backupPollInterval = Duration(seconds: 5);

  int _tempIdCounter = 0;

  String _makeTempId() =>
      'temp_${DateTime.now().millisecondsSinceEpoch}_${_tempIdCounter++}';

  int? get _lastConfirmedId {
    final ids = _messages
        .where((m) => m['id'] != null)
        .map((m) => m['id'] as int);
    if (ids.isEmpty) return null;
    return ids.reduce((a, b) => a > b ? a : b);
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _init();
  }

  Future<void> _init() async {
    // On charge l'utilisateur courant avant d'écouter le socket pour que le
    // filtrage « mon propre message » fonctionne dès le premier événement.
    await _loadCurrentUser();
    _attachSocket();
    await _loadInitialMessages();
    _startBackupPoll();
  }

  void _startBackupPoll() {
    _backupPollTimer?.cancel();
    _backupPollTimer = Timer.periodic(_backupPollInterval, (_) {
      if (mounted) _syncMissedMessages();
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _scrollController.dispose();
    _backupPollTimer?.cancel();
    _stopTypingDebounce?.cancel();
    for (final t in _typingTimeouts.values) {
      t.cancel();
    }
    _messageSub?.cancel();
    _typingSub?.cancel();
    _connectionSub?.cancel();
    // On ne ferme PAS le socket partagé : il reste vivant pour la liste et les
    // autres conversations. On signale juste l'arrêt de frappe.
    _chatSocket.emitStopTyping(widget.conversationId);
    _messageController.dispose();
    super.dispose();
  }

  // ─── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getUser();
    if (mounted && user != null) {
      setState(() {
        _currentUserId = user['id'] as int?;
        _currentUsername = (user['username'] as String?) ?? '';
      });
    }
  }

  Future<void> _loadInitialMessages() async {
    try {
      final msgs = await _chatService.getMessages(widget.conversationId);
      if (mounted) {
        setState(() {
          _messages = msgs
              .map((m) => _normalize(m as Map<String, dynamic>))
              .toList();
          _isLoading = false;
          _messagesLoaded = true;
        });
        _jumpToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e is ApiException ? e.message : 'Erreur de chargement');
      }
    }
  }

  Future<void> _syncMissedMessages() async {
    if (!_messagesLoaded) return;
    final lastId = _lastConfirmedId;
    debugPrint('[sync] syncMissedMessages lastId=$lastId');
    if (lastId == null) {
      // Chat was empty on initial load — reload to catch any first messages
      await _loadInitialMessages();
      return;
    }
    try {
      final fresh = await _chatService.getMessages(
        widget.conversationId,
        after: lastId,
      );
      debugPrint('[sync] ${fresh.length} messages récupérés après id=$lastId');
      if (!mounted || fresh.isEmpty) return;
      final existingIds =
          _messages.where((m) => m['id'] != null).map((m) => m['id']).toSet();
      final toAdd = fresh
          .where((m) => !existingIds.contains((m as Map)['id']))
          .map((m) => _normalize(m as Map<String, dynamic>))
          .toList();
      debugPrint('[sync] ${toAdd.length} nouveaux messages à ajouter');
      if (toAdd.isNotEmpty) {
        setState(() => _messages.addAll(toAdd));
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[sync] erreur: $e');
    }
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) => {
        'id': raw['id'],
        'tempId': null,
        'content': raw['content'],
        'sender': raw['sender'],
        'createdAt': raw['createdAt'],
        'pending': false,
        'failed': false,
      };

  // ─── Socket ─────────────────────────────────────────────────────────────────

  void _attachSocket() {
    // Le socket partagé est connecté au niveau de l'app (après login). On
    // s'assure simplement qu'il est actif, on rejoint la room (utile pour une
    // conversation créée après la connexion) et on s'abonne aux flux filtrés.
    _chatSocket.connect();
    _chatSocket.joinRoom(widget.conversationId);
    _socketWasConnected = _chatSocket.isConnected;

    _messageSub = _chatSocket.messages.listen(_onSocketMessage);
    _typingSub = _chatSocket.typingEvents.listen(_onTypingEvent);

    _connectionSub = _chatSocket.connectionState.listen((connected) {
      if (connected) {
        _chatSocket.joinRoom(widget.conversationId);
        if (_socketWasConnected) _syncMissedMessages();
        _socketWasConnected = true;
      } else {
        // WS just dropped : poll immédiatement pour ne pas attendre le prochain
        // tick (jusqu'à 5 s) avant de récupérer un message arrivé pile à la coupure.
        _syncMissedMessages();
      }
    });
  }

  void _onSocketMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    if (msg['conversationId'] != widget.conversationId) return;

    final senderId = (msg['sender'] as Map?)?['id'] as int?;
    if (senderId != null && senderId == _currentUserId) return;

    final alreadyExists = _messages.any((m) => m['id'] == msg['id']);
    if (alreadyExists) return;

    setState(() => _messages.add(_normalize(msg)));
    _scrollToBottom();
  }

  void _onTypingEvent(Map<String, dynamic> data) {
    if (data['conversationId'] != widget.conversationId) return;
    final userId = data['userId'] as int?;
    if (userId == null || userId == _currentUserId) return;

    if (data['typing'] == true) {
      final username = data['username'] as String? ?? '';
      _typingTimeouts[userId]?.cancel();
      _typingTimeouts[userId] =
          Timer(const Duration(seconds: 5), () => _clearTypingUser(userId));
      if (mounted) setState(() => _typingUsers[userId] = username);
    } else {
      _clearTypingUser(userId);
    }
  }

  void _clearTypingUser(int userId) {
    _typingTimeouts.remove(userId)?.cancel();
    if (mounted) setState(() => _typingUsers.remove(userId));
  }

  // ─── Typing detection ────────────────────────────────────────────────────────

  void _onTextChanged() {
    if (_messageController.text.isEmpty) {
      _stopTypingDebounce?.cancel();
      if (_isTyping) {
        _isTyping = false;
        _chatSocket.emitStopTyping(widget.conversationId);
      }
      return;
    }
    if (!_isTyping) {
      _isTyping = true;
      _chatSocket.emitTyping(widget.conversationId);
    }
    _stopTypingDebounce?.cancel();
    _stopTypingDebounce = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      _chatSocket.emitStopTyping(widget.conversationId);
    });
  }

  // ─── Send message ────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final tempId = _makeTempId();
    _messageController.clear();
    _stopTypingDebounce?.cancel();
    _isTyping = false;
    _chatSocket.emitStopTyping(widget.conversationId);

    // 1. Optimistic insert
    final pending = <String, dynamic>{
      'id': null,
      'tempId': tempId,
      'content': text,
      'sender': {'id': _currentUserId, 'username': _currentUsername},
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'pending': true,
      'failed': false,
    };
    setState(() => _messages.add(pending));
    _scrollToBottom();

    try {
      final confirmed = await _chatService.sendMessage(
        widget.conversationId,
        text,
      );
      if (!mounted) return;

      final pendingIdx =
          _messages.indexWhere((m) => m['tempId'] == tempId);
      final alreadyById = _messages
          .any((m) => m['id'] != null && m['id'] == confirmed['id']);

      setState(() {
        if (pendingIdx >= 0) {
          // Replace pending with server-confirmed message
          _messages[pendingIdx] = _normalize(confirmed);
        } else if (!alreadyById) {
          // Pending already gone (WS beat HTTP) but id not yet in list — add
          _messages.add(_normalize(confirmed));
        }
        // else: WS already added the confirmed message — nothing to do
      });
    } catch (e) {
      if (!mounted) return;
      final idx = _messages.indexWhere((m) => m['tempId'] == tempId);
      if (idx >= 0) {
        setState(() {
          _messages[idx] = Map<String, dynamic>.from(_messages[idx])
            ..['pending'] = false
            ..['failed'] = true;
        });
      }
      _showError(e is ApiException ? e.message : "Erreur d'envoi");
    }
  }

  void _retryMessage(String tempId, String content) {
    setState(() => _messages.removeWhere((m) => m['tempId'] == tempId));
    _messageController.text = content;
    _sendMessage();
  }

  // ─── Scroll helpers ──────────────────────────────────────────────────────────

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 120) {
        _scrollController.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Misc ────────────────────────────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: paperDanger),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return DateFormat('HH:mm').format(dt);
  }

  String _typingText() {
    final names = _typingUsers.values.toList();
    if (names.length == 1) return '${names.first} est en train d\'écrire…';
    return '${names.join(', ')} sont en train d\'écrire…';
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appBarActions = [
      if (widget.isGroup)
        IconButton(
          icon: const Icon(Icons.groups_outlined),
          tooltip: 'Membres du groupe',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  GroupMembersPage(conversationId: widget.conversationId),
            ),
          ),
        ),
    ];

    // Conversation 1-à-1 : pas d'onglets, juste le chat.
    if (!widget.isGroup) {
      return Scaffold(
        backgroundColor: paperBg,
        appBar: paperAppBar(
          title: widget.conversationName,
          actions: appBarActions,
        ),
        body: _buildChatBody(),
      );
    }

    // Groupe : onglets Chat / Défis / Feed privé.
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: paperBg,
        appBar: paperAppBar(
          title: widget.conversationName,
          actions: appBarActions,
          bottom: paperTabBar(const [
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
            Tab(icon: Icon(Icons.emoji_events_outlined), text: 'Défis'),
            Tab(icon: Icon(Icons.photo_library_outlined), text: 'Feed'),
          ]),
        ),
        body: TabBarView(
          children: [
            _buildChatBody(),
            GroupChallengesTab(conversationId: widget.conversationId),
            GroupFeedTab(conversationId: widget.conversationId),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBody() {
    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: paperAccent),
                )
              : _messages.isEmpty
                  ? const PaperEmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'Aucun message',
                      message: 'Lance la conversation !',
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _buildBubble(_messages[i]),
                    ),
        ),
        if (_typingUsers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              // liveRegion : le lecteur d'écran annonce la frappe sans
              // que l'utilisateur ait à explorer la page.
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _typingText(),
                  style: paperMuted(fontSize: 12).copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        _buildInput(),
      ],
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final sender = msg['sender'] as Map?;
    final senderId = sender?['id'] as int?;
    final isMe = senderId != null && senderId == _currentUserId;
    final senderName = sender?['username'] as String? ?? '';
    final content = msg['content'] as String? ?? '';
    final time = _formatTime(msg['createdAt'] as String?);
    final isPending = msg['pending'] as bool? ?? false;
    final isFailed = msg['failed'] as bool? ?? false;
    final tempId = msg['tempId'] as String?;

    final Color bubbleColor;
    final Color textColor;
    if (isFailed) {
      bubbleColor = const Color(0xFFF7DAD4);
      textColor = paperInk;
    } else if (isMe) {
      // Accent foncé : contraste ≥ 5.5:1 avec le texte blanc.
      bubbleColor = isPending
          ? paperAccentStrong.withValues(alpha: 0.72)
          : paperAccentStrong;
      textColor = Colors.white;
    } else {
      bubbleColor = paperCard;
      textColor = paperInk;
    }

    final who = isMe ? 'Toi' : (senderName.isEmpty ? 'Inconnu' : senderName);
    final status = isFailed
        ? ", envoi échoué, appuie pour réessayer"
        : isPending
            ? ", en cours d'envoi"
            : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            ExcludeSemantics(
              child: FeedAvatar(
                username: senderName,
                avatarUrl: sender?['avatarUrl']?.toString(),
                avatarKey: sender?['avatarKey']?.toString(),
                size: 30,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            // Une bulle = une seule annonce, qui porte l'auteur, l'heure et
            // l'état d'envoi.
            child: Semantics(
              container: true,
              button: isFailed,
              label: '$who, $time : $content$status',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: isFailed && tempId != null
                    ? () => _retryMessage(tempId, content)
                    : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    border: isMe
                        ? null
                        : Border.all(color: paperBorder),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isMe && widget.isGroup)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            senderName,
                            style: paperLabel(
                              fontSize: 12,
                              color: paperAccentStrong,
                            ),
                          ),
                        ),
                      Text(
                        content,
                        style: paperMuted(fontSize: 15, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: paperMuted(
                              fontSize: 11,
                              color: textColor.withValues(alpha: 0.75),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              isFailed
                                  ? Icons.error_outline
                                  : isPending
                                      ? Icons.access_time
                                      : Icons.done,
                              size: 13,
                              color: isFailed
                                  ? paperDanger
                                  : textColor.withValues(alpha: 0.75),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: paperCard,
        border: Border(top: BorderSide(color: paperBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: 5,
                minLines: 1,
                style: paperMuted(fontSize: 15, color: paperInk),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: paperMuted(fontSize: 15),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFFE7D3B5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: paperAccent, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 48x48 : cible tactile minimale recommandée.
            IconButton.filled(
              onPressed: _sendMessage,
              tooltip: 'Envoyer',
              icon: const Icon(Icons.send, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: paperAccentStrong,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
