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
  bool _showEmojiDrawer = false;
  Timer? _pollingTimer;
  String? _currentUsername;
  String? _loadError;
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
    if (_isFetching) return;
    _isFetching = true;
    final revision = _messageRevision;
    try {
      final list = await ApiService().getChatMessages();
      if (!mounted || revision != _messageRevision) return;

      final previousLastId = _messages.isEmpty ? null : _messages.last['id'];
      final nearBottom =
          !_scrollCtrl.hasClients || _scrollCtrl.position.extentAfter < 100;
      setState(() {
        _messages = list;
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
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
      _showError(error.message);
    } on PlatformException {
      _showError('The attachment could not be read. Please select it again.');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: Colors.teal,
              ),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAttachment(ImageSource.camera, false);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: Colors.blue,
              ),
              title: const Text('Choose Photo from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAttachment(ImageSource.gallery, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_rounded, color: Colors.purple),
              title: const Text('Record or Select Video'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAttachment(ImageSource.gallery, true);
              },
            ),
          ],
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
    });
  }

  void _startEdit(Map<String, dynamic> msg) {
    if (_isSending || _isPicking) return;
    setState(() {
      _editingMsgId = msg['id'];
      _textCtrl.text = msg['message'] ?? '';
      _replyingTo = null;
      _attachment = null;
      _uploadedAttachment = null;
      _attachedMediaType = null;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myDisplayName = _getMyDisplayName();
    final canCompose = _currentUsername != null && !_isSending && !_isPicking;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.forum_outlined, color: Colors.teal, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Live Community Chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              'Chatting as: $myDisplayName',
              style: const TextStyle(fontSize: 11, color: Colors.teal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh messages',
            onPressed: () => _loadMessages(initial: false),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live connection status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _loadError != null || _isLoading
                        ? Colors.orange
                        : Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _loadError ??
                        (_isLoading
                            ? 'Loading community messages...'
                            : _currentUsername == null
                            ? 'Everyone can read. Sign in to send messages and attachments.'
                            : 'Shared community chat · Photos and videos up to 20 MB'),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.teal.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _loadError == null
                              ? 'No messages yet'
                              : 'Unable to load messages',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentUsername == null
                              ? 'Sign in to join the conversation.'
                              : 'Say hi to the community as $myDisplayName!',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final msgId = msg['id'] ?? '';
                      final sender = msg['username'] ?? 'Anonymous';
                      final isMe =
                          _currentUsername != null &&
                          msg['user_id'] == _currentUsername;
                      final text = msg['message'] ?? '';
                      final mediaUrl = msg['media_url'] ?? '';
                      final mediaType = msg['media_type'] ?? '';
                      final replyUser = msg['reply_to_username'] ?? '';
                      final replyText = msg['reply_to_message'] ?? '';
                      final isEdited = (msg['is_edited'] ?? 0) == 1;
                      final timeStr = _formatTime(msg['created_at'] ?? '');

                      return Padding(
                        key: ValueKey('chat-message-$msgId'),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.teal.shade100,
                                child: Text(
                                  sender.isNotEmpty
                                      ? sender[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],

                            // Quick Action Buttons for MY messages (Left side of my bubble)
                            if (isMe) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Delete message',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _isSending
                                    ? null
                                    : () => _deleteMessage(msgId),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: Colors.blueAccent,
                                ),
                                tooltip: 'Edit message',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: canCompose
                                    ? () => _startEdit(msg)
                                    : null,
                              ),
                              const SizedBox(width: 6),
                            ],

                            Flexible(
                              child: GestureDetector(
                                onLongPress: () => _showMsgActions(msg, isMe),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? theme.colorScheme.primary
                                        : theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(
                                        isMe ? 16 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 4 : 16,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      // Display Name Header
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          sender,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isMe
                                                ? theme.colorScheme.onPrimary
                                                      .withValues(alpha: 0.9)
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant
                                                      .withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ),

                                      // Quoted reply block
                                      if (replyUser.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: const Border(
                                              left: BorderSide(
                                                color: Colors.tealAccent,
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
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                replyText,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),

                                      // Media attachment renderer
                                      if (mediaUrl.isNotEmpty) ...[
                                        ChatMedia(
                                          url: mediaUrl,
                                          type: mediaType,
                                        ),
                                        const SizedBox(height: 6),
                                      ],

                                      // Text body
                                      if (text.isNotEmpty)
                                        Text(
                                          text,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isMe
                                                ? theme.colorScheme.onPrimary
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                        ),

                                      const SizedBox(height: 4),

                                      // Footer time & edited status + Quick reply icon
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isEdited)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 4,
                                              ),
                                              child: Text(
                                                '(edited)',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontStyle: FontStyle.italic,
                                                  color: isMe
                                                      ? theme
                                                            .colorScheme
                                                            .onPrimary
                                                            .withValues(
                                                              alpha: 0.7,
                                                            )
                                                      : theme
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                ),
                                              ),
                                            ),
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isMe
                                                  ? theme.colorScheme.onPrimary
                                                        .withValues(alpha: 0.7)
                                                  : theme
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                        .withValues(alpha: 0.6),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () => _startReply(msg),
                                            child: Icon(
                                              Icons.reply_rounded,
                                              size: 14,
                                              color: isMe
                                                  ? theme.colorScheme.onPrimary
                                                        .withValues(alpha: 0.8)
                                                  : theme
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                        .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Active Reply / Edit Header Banner
          if (_replyingTo != null ||
              _editingMsgId != null ||
              _attachment != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(
                    _editingMsgId != null
                        ? Icons.edit_rounded
                        : _attachment != null
                        ? Icons.attach_file_rounded
                        : Icons.reply_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _editingMsgId != null
                          ? 'Editing message...'
                          : _attachment != null
                          ? '$_attachedMediaType attached: ${_attachment!.name}'
                          : 'Replying to ${_replyingTo!['username']}: ${_replyingTo!['message']}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Clear attachment or reply',
                    onPressed: _isSending
                        ? null
                        : () {
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
            ),

          // Message input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Emoji & Sticker button
                      IconButton(
                        tooltip: 'Emojis and stickers',
                        icon: Icon(
                          _showEmojiDrawer
                              ? Icons.keyboard_hide_rounded
                              : Icons.emoji_emotions_outlined,
                          color: Colors.amber.shade700,
                        ),
                        onPressed: canCompose
                            ? () {
                                setState(
                                  () => _showEmojiDrawer = !_showEmojiDrawer,
                                );
                              }
                            : null,
                      ),
                      // Media attachment button
                      IconButton(
                        tooltip: 'Attach photo or video',
                        icon: const Icon(
                          Icons.attach_file_rounded,
                          color: Colors.teal,
                        ),
                        onPressed: canCompose && _editingMsgId == null
                            ? _showAttachmentMenu
                            : null,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          enabled: canCompose,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: _currentUsername == null
                                ? 'Sign in to send messages'
                                : _editingMsgId != null
                                ? 'Edit your message...'
                                : 'Type a message as $myDisplayName...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Send message',
                        onPressed: canCompose ? _sendMessage : null,
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _editingMsgId != null
                                    ? Icons.check_rounded
                                    : Icons.send_rounded,
                              ),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),

                  // Emoji & Sticker Drawer
                  if (_showEmojiDrawer) _buildEmojiStickerDrawer(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMsgActions(Map<String, dynamic> msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.teal),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                _startReply(msg);
              },
            ),
            if (isMe) ...[
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.blue),
                title: const Text('Edit Message'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEdit(msg);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                ),
                title: const Text('Delete Message'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(msg['id'] ?? '');
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiStickerDrawer(ThemeData theme) {
    final emojis = [
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
    final stickers = [
      '🇨🇲 Yaoundé Explorer',
      '🦁 Indomitable Lion',
      '⛰️ Mont Fébé Legend',
      '☕ Cameroon Coffee',
      '🚌 Voyage Express',
      '🍲 Ndolé Gourmet',
    ];

    return Container(
      height: 180,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: '😃 Emojis'),
                Tab(text: '🎨 Stickers'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Emojis Grid
                  GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: emojis.length,
                    itemBuilder: (ctx, i) {
                      return InkWell(
                        onTap: _isSending
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
                      );
                    },
                  ),
                  // Stickers List
                  ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: stickers.length,
                    itemBuilder: (ctx, i) {
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          dense: true,
                          title: Text(
                            stickers[i],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: const Icon(
                            Icons.send_rounded,
                            size: 16,
                            color: Colors.teal,
                          ),
                          onTap: _isSending
                              ? null
                              : () {
                                  setState(() => _showEmojiDrawer = false);
                                  _sendSticker(stickers[i]);
                                },
                        ),
                      );
                    },
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
