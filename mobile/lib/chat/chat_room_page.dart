import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../services/chat_service.dart';
import '../services/chat_socket_service.dart';
import '../services/api_exception.dart';
import 'group_members_page.dart';

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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversationName),
        actions: [
          if (widget.isGroup)
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: 'Membres du groupe',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      GroupMembersPage(conversationId: widget.conversationId),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun message. Lancez la conversation !',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 10),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildBubble(_messages[i]),
                      ),
          ),
          if (_typingUsers.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _typingText(),
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final senderId = (msg['sender'] as Map?)?['id'] as int?;
    final isMe = senderId != null && senderId == _currentUserId;
    final senderName =
        (msg['sender'] as Map?)?['username'] as String? ?? '';
    final content = msg['content'] as String? ?? '';
    final time = _formatTime(msg['createdAt'] as String?);
    final isPending = msg['pending'] as bool? ?? false;
    final isFailed = msg['failed'] as bool? ?? false;
    final tempId = msg['tempId'] as String?;

    final bubbleColor = isFailed
        ? Colors.red[100]!
        : isPending
            ? Colors.blue[200]!
            : isMe
                ? Colors.blue[400]!
                : Colors.grey[200]!;

    final textColor = isMe && !isFailed ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blueGrey[200],
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style:
                    const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          if (!isMe) const SizedBox(width: 6),
          Flexible(
            child: GestureDetector(
              onTap: isFailed && tempId != null
                  ? () => _retryMessage(tempId, content)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
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
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[600],
                          ),
                        ),
                      ),
                    Text(
                      content,
                      style:
                          TextStyle(fontSize: 15, color: textColor),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 10,
                            color: textColor.withValues(alpha: 0.65),
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
                            size: 12,
                            color: isFailed
                                ? Colors.red
                                : textColor.withValues(alpha: 0.65),
                          ),
                        ],
                      ],
                    ),
                  ],
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, -1))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Message…',
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.blue[600],
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _sendMessage,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
