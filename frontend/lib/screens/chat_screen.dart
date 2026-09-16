import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/chat_media.dart';

/// Rich Live Community Chatroom with Simple Edit, Delete & Custom Display Name support.
class ChatScreen extends StatefulWidget {
  final void Function(Locale)? onLocaleChanged;
  final ImagePicker? imagePicker;
  const ChatScreen({super.key, this.onLocaleChanged, this.imagePicker});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late final ImagePicker _picker;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isPicking = false;
  bool _isFetching = false;
  bool _isFetchingHistory = false;
  bool _hasOlderMessages = false;
  bool _initialScrollComplete = false;
  String? _historyError;
  Map<String, dynamic>? _historyAnchor;
  static const int _pageSize = 100;
  bool _showEmojiDrawer = false;
  Timer? _pollingTimer;
  String? _currentUsername;
  String? _loadError;
  String? _sendError;
  String? _failedSticker;
  bool _sendOutcomeUnknown = false;
  int _messageRevision = 0;

  // Active state for Reply & Edit
  Map<String, String>? _replyingTo;
  String? _editingMsgId;
  XFile? _attachment;
  String? _attachedMediaType;
  ChatAttachment? _uploadedAttachment;

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
    _scrollCtrl.addListener(_onConversationScroll);
    AuthProvider().addListener(_loadSession);
    _loadSession();
    _loadMessages(initial: true);
    // Poll for live community updates every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMessages(initial: false);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    AuthProvider().removeListener(_loadSession);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _getMyDisplayName() {
    return _currentUsername ?? 'Guest';
  }

  Future<void> _loadSession() async {
    final username = await ApiService().getChatUsername();
    if (mounted) setState(() => _currentUsername = username);
  }

  Future<void> _loadMessages({bool initial = false}) async {
    if (!mounted || _isFetching) return;
    setState(() => _isFetching = true);
    final revision = _messageRevision;
    try {
      final list = await ApiService().getChatMessages(limit: _pageSize);
      if (!mounted || revision != _messageRevision) return;

      final previousLastId = _messages.isEmpty ? null : _messages.last['id'];
      final nearBottom =
          !_scrollCtrl.hasClients || _scrollCtrl.position.extentAfter < 100;
      setState(() {
        if (_historyAnchor == null && list.isNotEmpty) {
          _historyAnchor = list.first;
          _hasOlderMessages = list.length == _pageSize;
        }
        _messages = list.isEmpty
            ? []
            : _mergeMessages([
                ..._messages.where(
                  (message) => _compareMessages(message, list.first) < 0,
                ),
                ...list,
              ]);
        if (list.isEmpty) {
          _hasOlderMessages = false;
          _historyAnchor = null;
        }
        _loadError = null;
      });

      if (initial ||
          (nearBottom &&
              list.isNotEmpty &&
              list.last['id'] != previousLastId)) {
        _scrollToBottom();
      }
    } on ApiException catch (error) {
      if (mounted && revision == _messageRevision) {
        setState(() => _loadError = error.message);
      }
    } finally {
      _isFetching = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollCtrl.hasClients) {
        _scrollCtrl
            .animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            )
            .whenComplete(() => _initialScrollComplete = true);
      }
    });
  }

  String _messageField(Map<String, dynamic> message, String name) {
    final value = message[name];
    if (value is! String || value.isEmpty) {
      throw ApiException(
        502,
        'The chat server returned an invalid history cursor.',
      );
    }
    return value;
  }

  int _compareMessages(Map<String, dynamic> a, Map<String, dynamic> b) {
    final time = _messageField(
      a,
      'created_at',
    ).compareTo(_messageField(b, 'created_at'));
    return time != 0
        ? time
        : _messageField(a, 'id').compareTo(_messageField(b, 'id'));
  }

  List<Map<String, dynamic>> _mergeMessages(
    List<Map<String, dynamic>> messages,
  ) {
    final byId = {
      for (final message in messages) _messageField(message, 'id'): message,
    };
    return byId.values.toList()..sort(_compareMessages);
  }

  void _onConversationScroll() {
    if (_initialScrollComplete &&
        _historyError == null &&
        _scrollCtrl.hasClients &&
        _scrollCtrl.position.pixels <=
            _scrollCtrl.position.minScrollExtent + 80) {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _loadOlderMessages() async {
    if (!mounted ||
        _isLoading ||
        _isFetchingHistory ||
        !_hasOlderMessages ||
        _messages.isEmpty) {
      return;
    }
    final oldest = _messages.first;
    final revision = _messageRevision;
    setState(() {
      _isFetchingHistory = true;
      _historyError = null;
    });
    try {
      final older = await ApiService().getChatMessages(
        limit: _pageSize,
        beforeCreatedAt: _messageField(oldest, 'created_at'),
        beforeId: _messageField(oldest, 'id'),
      );
      if (!mounted || revision != _messageRevision) return;
      if (older.any((message) => _compareMessages(message, oldest) >= 0)) {
        throw ApiException(
          502,
          'The server did not return older messages. Please update the chat service.',
        );
      }
      setState(() {
        _messages = _mergeMessages([...older, ..._messages]);
        _hasOlderMessages = older.length == _pageSize;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _historyError = error.message);
    } finally {
      if (mounted) setState(() => _isFetchingHistory = false);
    }
  }

  Future<void> _sendMessage({String? sticker}) async {
    if (_isSending || _isPicking) return;
    if (_currentUsername == null) {
      _showError('Please sign in to send community messages.');
      return;
    }
    final text = sticker == null ? _textCtrl.text.trim() : '';
    if (text.isEmpty && _attachment == null && sticker == null) return;

    final myName = _getMyDisplayName();
    final reply = sticker == null ? _replyingTo : null;
    final editingId = sticker == null ? _editingMsgId : null;

    setState(() => _isSending = true);

    try {
      if (editingId != null) {
        await ApiService().editChatMessage(editingId, text, username: myName);
        if (!mounted) return;
        _messageRevision++;
        setState(() {
          _messages = [
            for (final message in _messages)
              if (message['id'] == editingId)
                {...message, 'message': text, 'is_edited': 1}
              else
                message,
          ];
        });
      } else {
        final attachment = _attachment;
        if (sticker == null &&
            attachment != null &&
            _uploadedAttachment == null) {
          final bytes = await attachment.readAsBytes();
          _uploadedAttachment = await ApiService().uploadChatMedia(
            bytes,
            filename: attachment.name,
          );
          if (!mounted) return;
        }
        final newMsg = await ApiService().sendChatMessage(
          text,
          username: myName,
          mediaUrl: sticker ?? _uploadedAttachment?.url,
          mediaType: sticker != null ? 'sticker' : _uploadedAttachment?.type,
          replyToId: reply?['id'],
          replyToUsername: reply?['username'],
          replyToMessage: reply?['message'],
        );
        if (!mounted) return;
        _messageRevision++;
        setState(() {
          _messages = [
            ..._messages.where((message) => message['id'] != newMsg['id']),
            newMsg,
          ];
        });
        unawaited(AnalyticsService().logSendChatMessage());
      }
      _clearSendFailure();
      if (sticker == null) {
        _textCtrl.clear();
        setState(() {
          _attachment = null;
          _uploadedAttachment = null;
          _attachedMediaType = null;
          _replyingTo = null;
          _editingMsgId = null;
        });
      }
      _scrollToBottom();
    } on ApiException catch (error) {
      _recordSendFailure(
        error.message,
        sticker: sticker,
        outcomeUnknown: error.statusCode == 0 || error.statusCode == 408,
      );
    } on PlatformException {
      _recordSendFailure(
        'The attachment could not be read. Please select it again.',
        sticker: sticker,
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _recordSendFailure(
    String message, {
    String? sticker,
    bool outcomeUnknown = false,
  }) {
    if (!mounted) return;
    setState(() {
      _sendError = message;
      _failedSticker = sticker;
      _sendOutcomeUnknown = outcomeUnknown;
    });
    _showError(message);
  }

  void _clearSendFailure() {
    if (!mounted || _sendError == null) return;
    setState(() {
      _sendError = null;
      _failedSticker = null;
      _sendOutcomeUnknown = false;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  Future<void> _pickAttachment(ImageSource source, bool isVideo) async {
    if (_isSending || _isPicking) return;
    setState(() => _isPicking = true);
    try {
      XFile? file;
      if (isVideo) {
        file = await _picker.pickVideo(source: source);
      } else {
        file = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
        );
      }
      if (file == null) return;

      final length = await file.length();
      if (!mounted) return;
      if (length == 0 || length > ApiService.maxChatMediaBytes) {
        _showError('Choose a non-empty photo or video of 20 MB or smaller.');
        return;
      }
      setState(() {
        _attachment = file;
        _uploadedAttachment = null;
        _attachedMediaType = isVideo ? 'video' : 'image';
      });
    } on PlatformException catch (error) {
      _showError(error.message ?? 'Could not attach this file.');
    } on UnsupportedError {
      _showError('This attachment source is not supported on this device.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_camera_rounded,
                  color: scheme.primary,
                ),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAttachment(ImageSource.camera, false);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_rounded,
                  color: scheme.primary,
                ),
                title: const Text('Choose Photo from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAttachment(ImageSource.gallery, false);
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam_rounded, color: scheme.primary),
                title: const Text('Record or Select Video'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAttachment(ImageSource.gallery, true);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String msgId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await ApiService().deleteChatMessage(
          msgId,
          username: _getMyDisplayName(),
        );
        if (!mounted) return;
        _messageRevision++;
        setState(() {
          _messages.removeWhere((message) => message['id'] == msgId);
        });
      } on ApiException catch (error) {
        _showError(error.message);
      }
    }
  }

  void _startReply(Map<String, dynamic> msg) {
    if (_isSending || _currentUsername == null) return;
    setState(() {
      _replyingTo = {
        'id': msg['id'] ?? '',
        'username': msg['username'] ?? 'Anonymous',
        'message': msg['message'] ?? '',
      };
      _editingMsgId = null;
      _showEmojiDrawer = false;
    });
  }

  void _startEdit(Map<String, dynamic> msg) {
    if (_isSending || _isPicking) return;
    _clearSendFailure();
    setState(() {
      _editingMsgId = msg['id'];
      _textCtrl.text = msg['message'] ?? '';
      _replyingTo = null;
      _attachment = null;
      _uploadedAttachment = null;
      _attachedMediaType = null;
      _showEmojiDrawer = false;
    });
  }

  void _sendSticker(String stickerLabel) {
    _sendMessage(sticker: stickerLabel);
  }

  String _formatTime(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }

  void _closeEmojiDrawer() {
    if (_showEmojiDrawer) setState(() => _showEmojiDrawer = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final wide = media.size.width >= 760;
    final short = media.size.height - media.viewInsets.bottom < 440;
    final canCompose = _currentUsername != null && !_isSending && !_isPicking;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        toolbarHeight: short ? 64 : 80,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            if (wide) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.forum_outlined,
                  color: scheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wide ? 'Live Community Chat' : 'Community chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: wide ? 22 : 19,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentUsername == null
                        ? 'Everyone can read. Sign in to join.'
                        : 'Chatting as: ${_getMyDisplayName()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh messages',
              onPressed: _isFetching
                  ? null
                  : () => _loadMessages(initial: false),
              style: IconButton.styleFrom(
                foregroundColor: scheme.primary,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 960),
            margin: EdgeInsets.symmetric(
              horizontal: wide ? 24 : 0,
              vertical: wide && !short ? 20 : 0,
            ),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(wide ? 24 : 0),
              border: wide ? Border.all(color: scheme.outlineVariant) : null,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final splitComposer =
                    constraints.maxWidth < 480 && constraints.maxHeight >= 250;
                return Column(
                  children: [
                    _buildRoomStatus(theme, constraints.maxWidth),
                    if (_loadError != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: (constraints.maxHeight * 0.3).clamp(
                            0.0,
                            160.0,
                          ),
                        ),
                        child: SingleChildScrollView(
                          primary: false,
                          child: _buildLoadError(theme),
                        ),
                      ),
                    Expanded(child: _buildConversationArea(theme, canCompose)),
                    _buildComposer(
                      theme,
                      canCompose: canCompose,
                      split: splitComposer,
                      contextMaxHeight: (constraints.maxHeight * 0.35).clamp(
                        64.0,
                        160.0,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomStatus(ThemeData theme, double width) {
    final scheme = theme.colorScheme;
    final hasError = _loadError != null || _sendError != null;
    final label = _sendError != null
        ? _isSending
              ? 'Sending again...'
              : _sendOutcomeUnknown
              ? 'Send not confirmed'
              : _failedSticker != null
              ? 'Sticker not sent'
              : 'Message not sent'
        : _loadError != null
        ? _isFetching
              ? 'Reconnecting...'
              : 'Updates unavailable'
        : _isLoading
        ? 'Loading community messages...'
        : 'Shared community chat';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: hasError ? scheme.errorContainer : scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasError ? Icons.cloud_off_outlined : Icons.public_rounded,
            size: 18,
            color: hasError ? scheme.onErrorContainer : scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: hasError
                    ? scheme.onErrorContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (width >= 680)
            Text(
              'Photos and videos up to 20 MB',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConversationArea(ThemeData theme, bool canCompose) {
    if (!_showEmojiDrawer) return _buildConversation(theme, canCompose);
    return LayoutBuilder(
      builder: (context, constraints) {
        // On a short viewport the drawer uses the conversation's space, never
        // the composer's. Opening a keyboard cannot push the send button away.
        if (constraints.maxHeight < 400) {
          return _buildEmojiStickerDrawer(theme);
        }
        return Column(
          children: [
            Expanded(child: _buildConversation(theme, canCompose)),
            SizedBox(height: 240, child: _buildEmojiStickerDrawer(theme)),
          ],
        );
      },
    );
  }

  Widget _buildConversation(ThemeData theme, bool canCompose) {
    final anchor = _historyAnchor;
    final older = anchor == null
        ? <Map<String, dynamic>>[]
        : _messages
              .where((message) => _compareMessages(message, anchor) < 0)
              .toList();
    final recent = _messages.skip(older.length).toList();
    const centerKey = ValueKey('chat-live-messages');
    return CustomScrollView(
      key: const ValueKey('chat-timeline'),
      controller: _scrollCtrl,
      center: _messages.isEmpty ? null : centerKey,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (_isLoading || _messages.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyState(theme))
        else ...[
          SliverToBoxAdapter(child: _buildHistoryStatus(theme)),
          // Slivers before the center grow upward without moving the reader.
          if (older.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              sliver: SliverList.builder(
                itemCount: older.length,
                itemBuilder: (context, index) => _buildMessage(
                  theme,
                  older[older.length - index - 1],
                  canCompose,
                ),
              ),
            ),
          SliverPadding(
            key: centerKey,
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
            sliver: SliverList.builder(
              itemCount: recent.length,
              itemBuilder: (context, index) =>
                  _buildMessage(theme, recent[index], canCompose),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistoryStatus(ThemeData theme) {
    if (_historyError != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              _historyError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            TextButton.icon(
              onPressed: _isFetchingHistory ? null : _loadOlderMessages,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry older messages'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        _isFetchingHistory
            ? 'Loading older messages...'
            : _hasOlderMessages
            ? 'Scroll up for earlier conversations'
            : 'Beginning of the conversation',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildLoadError(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _loadError!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _messages.isEmpty
                ? 'We will keep trying. You can also retry now.'
                : 'Your messages are still here. We will keep trying to update them.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isFetching ? null : () => _loadMessages(initial: false),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(_isFetching ? 'Reconnecting...' : 'Try again'),
            style: TextButton.styleFrom(
              foregroundColor: scheme.onErrorContainer,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: scheme.onPrimaryContainer,
                        ),
                      )
                    : Icon(
                        _loadError == null
                            ? Icons.waving_hand_outlined
                            : Icons.cloud_off_outlined,
                        size: 34,
                        color: scheme.onPrimaryContainer,
                      ),
              ),
              const SizedBox(height: 20),
              Text(
                _isLoading
                    ? 'Finding the conversation'
                    : _loadError == null
                    ? 'No messages yet'
                    : 'Unable to load messages',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isLoading
                    ? 'Fetching the latest community messages.'
                    : _loadError != null
                    ? 'The conversation will appear here when the connection is restored.'
                    : _currentUsername == null
                    ? 'Sign in to join the conversation.'
                    : 'Say hi to the community as ${_getMyDisplayName()}!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              if (!_isLoading && _loadError == null) ...[
                const SizedBox(height: 18),
                Text(
                  'Local tips, travel stories, and a little hello.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(
    ThemeData theme,
    Map<String, dynamic> msg,
    bool canCompose,
  ) {
    final scheme = theme.colorScheme;
    final msgId = msg['id'] ?? '';
    final sender = msg['username'] ?? 'Anonymous';
    final isMe = _currentUsername != null && msg['user_id'] == _currentUsername;
    final text = msg['message'] ?? '';
    final mediaUrl = msg['media_url'] ?? '';
    final mediaType = msg['media_type'] ?? '';
    final replyUser = msg['reply_to_username'] ?? '';
    final replyText = msg['reply_to_message'] ?? '';
    final isEdited = (msg['is_edited'] ?? 0) == 1;
    final time = _formatTime(msg['created_at'] ?? '');
    final foreground = isMe ? scheme.onPrimaryContainer : scheme.onSurface;

    return Padding(
      key: ValueKey('chat-message-$msgId'),
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final bubbleWidth = availableWidth > 680
              ? 600.0
              : availableWidth - (isMe ? 16 : 40);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.secondaryContainer,
                    foregroundColor: scheme.onSecondaryContainer,
                    child: Text(
                      sender.isNotEmpty ? sender[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bubbleWidth),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onLongPress: () => _showMsgActions(msg, isMe),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? scheme.primaryContainer
                                : scheme.surface,
                            border: Border.all(
                              color: isMe
                                  ? scheme.primary.withValues(alpha: 0.12)
                                  : scheme.outlineVariant.withValues(
                                      alpha: 0.7,
                                    ),
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(isMe ? 20 : 6),
                              topRight: Radius.circular(isMe ? 6 : 20),
                              bottomLeft: const Radius.circular(20),
                              bottomRight: const Radius.circular(20),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sender,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: isMe
                                      ? scheme.onPrimaryContainer
                                      : scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (replyUser.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? scheme.surface.withValues(alpha: 0.5)
                                        : scheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border(
                                      left: BorderSide(
                                        color: scheme.primary,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Replying to $replyUser',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: foreground,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        replyText,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: foreground),
                                      ),
                                    ],
                                  ),
                                ),
                              if (mediaUrl.isNotEmpty) ...[
                                ChatMedia(url: mediaUrl, type: mediaType),
                                if (text.isNotEmpty) const SizedBox(height: 10),
                              ],
                              if (text.isNotEmpty)
                                Text(
                                  text,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 15,
                                    height: 1.45,
                                    color: foreground,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Wrap(
                        alignment: isMe
                            ? WrapAlignment.end
                            : WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (time.isNotEmpty || isEdited)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                '${isEdited ? '(edited) · ' : ''}$time',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          IconButton(
                            tooltip: 'Reply',
                            icon: const Icon(Icons.reply_rounded, size: 19),
                            onPressed: canCompose
                                ? () => _startReply(msg)
                                : null,
                            style: IconButton.styleFrom(
                              foregroundColor: scheme.onSurfaceVariant,
                              minimumSize: const Size(48, 48),
                            ),
                          ),
                          if (isMe) ...[
                            IconButton(
                              tooltip: 'Edit message',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: canCompose
                                  ? () => _startEdit(msg)
                                  : null,
                              style: IconButton.styleFrom(
                                foregroundColor: scheme.onSurfaceVariant,
                                minimumSize: const Size(48, 48),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete message',
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 19,
                              ),
                              onPressed: _isSending
                                  ? null
                                  : () => _deleteMessage(msgId),
                              style: IconButton.styleFrom(
                                foregroundColor: scheme.onSurfaceVariant,
                                minimumSize: const Size(48, 48),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComposer(
    ThemeData theme, {
    required bool canCompose,
    required bool split,
    required double contextMaxHeight,
  }) {
    final scheme = theme.colorScheme;
    final tools = [
      IconButton(
        tooltip: 'Emojis and stickers',
        icon: Icon(
          _showEmojiDrawer
              ? Icons.keyboard_rounded
              : Icons.emoji_emotions_outlined,
        ),
        isSelected: _showEmojiDrawer,
        onPressed: canCompose
            ? () {
                if (!_showEmojiDrawer) {
                  FocusScope.of(context).unfocus();
                }
                setState(() => _showEmojiDrawer = !_showEmojiDrawer);
              }
            : null,
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(48, 48),
        ),
      ),
      IconButton(
        tooltip: 'Attach photo or video',
        icon: _isPicking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.attach_file_rounded),
        onPressed: canCompose && _editingMsgId == null
            ? _showAttachmentMenu
            : null,
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(48, 48),
        ),
      ),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_sendError != null ||
              _replyingTo != null ||
              _editingMsgId != null ||
              _attachment != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: contextMaxHeight),
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_sendError != null)
                      _buildSendFailure(theme, canCompose),
                    if (_replyingTo != null ||
                        _editingMsgId != null ||
                        _attachment != null)
                      _buildDraftContext(theme),
                  ],
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!split) ...tools,
              Expanded(
                key: const ValueKey('chat-message-input'),
                child: TextField(
                  controller: _textCtrl,
                  enabled: canCompose,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  onTap: _closeEmojiDrawer,
                  onChanged: (_) => _closeEmojiDrawer(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: _currentUsername == null
                        ? 'Sign in to send messages'
                        : _editingMsgId != null
                        ? 'Edit your message...'
                        : 'Write a message...',
                    hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: scheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send message',
                onPressed: canCompose ? _sendMessage : null,
                icon: _isSending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    : Icon(
                        _editingMsgId != null
                            ? Icons.check_rounded
                            : Icons.arrow_upward_rounded,
                      ),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          if (split)
            Row(
              children: [
                ...tools,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentUsername == null
                        ? 'Everyone can read.'
                        : _isSending
                        ? 'Sending...'
                        : 'Photos & videos · 20 MB',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSendFailure(ThemeData theme, bool canCompose) {
    final scheme = theme.colorScheme;
    final summary = _sendOutcomeUnknown
        ? 'Unconfirmed. Check before retrying.'
        : _failedSticker != null
        ? 'Sticker kept.'
        : 'Draft kept.';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: 'Send error details',
              child: TextButton(
                onPressed: _showSendFailureDetails,
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: scheme.onErrorContainer,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  '$summary $_sendError',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            hint: _failedSticker == null
                ? 'Retry the current draft. Nothing is sent automatically.'
                : 'Retry only the failed sticker. Your typed draft is kept.',
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _textCtrl,
              builder: (context, value, child) => IconButton(
                tooltip: 'Retry send',
                icon: const Icon(Icons.refresh_rounded),
                onPressed:
                    canCompose &&
                        (_failedSticker != null ||
                            value.text.trim().isNotEmpty ||
                            _attachment != null)
                    ? () => _sendMessage(sticker: _failedSticker)
                    : null,
                style: IconButton.styleFrom(
                  foregroundColor: scheme.onErrorContainer,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss send error',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: _isSending ? null : _clearSendFailure,
            style: IconButton.styleFrom(
              foregroundColor: scheme.onErrorContainer,
              minimumSize: const Size(48, 48),
            ),
          ),
        ],
      ),
    );
  }

  void _showSendFailureDetails() {
    final error = _sendError;
    if (error == null) return;
    final sticker = _failedSticker;
    final guidance = _sendOutcomeUnknown
        ? 'Check the conversation before retrying: the previous request may '
              'already have arrived. Nothing is resent automatically.'
        : 'Nothing is resent automatically. Use Retry send when you are ready.';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          _sendOutcomeUnknown
              ? 'Send not confirmed'
              : sticker == null
              ? 'Message not sent'
              : 'Sticker not sent',
        ),
        content: Text(
          '$error\n\n$guidance\n\n'
          '${sticker == null ? 'Your draft and attachments are kept.' : 'Retry sends only this sticker: $sticker. Your typed draft and attachments stay unchanged.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftContext(ThemeData theme) {
    final scheme = theme.colorScheme;
    final description = _editingMsgId != null
        ? 'Editing message...'
        : _attachment != null
        ? '$_attachedMediaType attached: ${_attachment!.name}'
        : 'Replying to ${_replyingTo!['username']}: ${_replyingTo!['message']}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _editingMsgId != null
                ? Icons.edit_rounded
                : _attachment != null
                ? Icons.attach_file_rounded
                : Icons.reply_rounded,
            size: 20,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Clear attachment or reply',
            style: IconButton.styleFrom(
              foregroundColor: scheme.onPrimaryContainer,
              minimumSize: const Size(48, 48),
            ),
            onPressed: _isSending
                ? null
                : () {
                    _clearSendFailure();
                    setState(() {
                      _replyingTo = null;
                      _editingMsgId = null;
                      _attachment = null;
                      _uploadedAttachment = null;
                      _attachedMediaType = null;
                    });
                  },
          ),
        ],
      ),
    );
  }

  void _showMsgActions(Map<String, dynamic> msg, bool isMe) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.reply_rounded, color: scheme.primary),
                title: const Text('Reply'),
                enabled: _currentUsername != null && !_isSending,
                onTap: () {
                  Navigator.pop(ctx);
                  _startReply(msg);
                },
              ),
              if (isMe) ...[
                ListTile(
                  leading: Icon(Icons.edit_rounded, color: scheme.primary),
                  title: const Text('Edit Message'),
                  enabled: !_isSending && !_isPicking,
                  onTap: () {
                    Navigator.pop(ctx);
                    _startEdit(msg);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_rounded,
                    color: scheme.error,
                  ),
                  title: const Text('Delete Message'),
                  enabled: !_isSending,
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteMessage(msg['id'] ?? '');
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiStickerDrawer(ThemeData theme) {
    const emojis = [
      '😊',
      '😂',
      '😍',
      '🔥',
      '👍',
      '❤️',
      '🎉',
      '🚀',
      '🇨🇲',
      '✨',
      '⭐',
      '🙌',
      '🤩',
      '🥳',
      '👏',
      '💯',
      '🌴',
      '✈️',
      '🗺️',
      '📸',
    ];
    const stickers = [
      '🇨🇲 Yaoundé Explorer',
      '🦁 Indomitable Lion',
      '⛰️ Mont Fébé Legend',
      '☕ Cameroon Coffee',
      '🚌 Voyage Express',
      '🍲 Ndolé Gourmet',
    ];
    final scheme = theme.colorScheme;
    final canCompose = _currentUsername != null && !_isSending && !_isPicking;
    final emojiHeight = MediaQuery.textScalerOf(context).scale(24) + 28;

    final drawer = Material(
      color: scheme.surfaceContainerLow,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              indicatorColor: scheme.primary,
              tabs: const [
                Tab(text: '😃 Emojis'),
                Tab(text: '🎨 Stickers'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 72,
                      mainAxisExtent: emojiHeight,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: emojis.length,
                    itemBuilder: (ctx, i) => Semantics(
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: !canCompose
                            ? null
                            : () {
                                final selection = _textCtrl.selection;
                                final start = selection.isValid
                                    ? selection.start
                                    : _textCtrl.text.length;
                                final end = selection.isValid
                                    ? selection.end
                                    : start;
                                _textCtrl.value = TextEditingValue(
                                  text: _textCtrl.text.replaceRange(
                                    start,
                                    end,
                                    emojis[i],
                                  ),
                                  selection: TextSelection.collapsed(
                                    offset: start + emojis[i].length,
                                  ),
                                );
                              },
                        child: Center(
                          child: Text(
                            emojis[i],
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: stickers.length,
                    itemBuilder: (ctx, i) => ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(
                        stickers[i],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      trailing: Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                      enabled: canCompose,
                      onTap: () {
                        setState(() => _showEmojiDrawer = false);
                        _sendSticker(stickers[i]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 140) {
          return SingleChildScrollView(
            child: SizedBox(height: 140, child: drawer),
          );
        }
        return drawer;
      },
    );
  }
}
