import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/analytics_service.dart';

/// Rich Live Community Chatroom with Simple Edit, Delete & Custom Display Name support.
class ChatScreen extends StatefulWidget {
  final void Function(Locale)? onLocaleChanged;
  const ChatScreen({super.key, this.onLocaleChanged});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _showEmojiDrawer = false;
  Timer? _pollingTimer;

  // Active state for Reply & Edit
  Map<String, String>? _replyingTo;
  String? _editingMsgId;
  String? _attachedMediaBase64;
  String? _attachedMediaType;

  @override
  void initState() {
    super.initState();
    _loadMessages(initial: true);
    // Poll for live community updates every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMessages(initial: false);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _getMyDisplayName() {
    final name = AuthProvider().username?.trim() ?? '';
    return name.isNotEmpty ? name : 'GlobeTrotter User';
  }

  Future<void> _loadMessages({bool initial = false}) async {
    try {
      final list = await ApiService().getChatMessages();
      if (!mounted) return;

      final previousCount = _messages.length;
      setState(() {
        _messages = list;
        if (initial) _isLoading = false;
      });

      if (initial || list.length > previousCount) {
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted && initial) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if ((text.isEmpty && _attachedMediaBase64 == null) || _isSending) return;

    final myName = _getMyDisplayName();
    final mediaUrl = _attachedMediaBase64;
    final mediaType = _attachedMediaType;
    final replyId = _replyingTo?['id'];
    final replyUser = _replyingTo?['username'];
    final replyText = _replyingTo?['message'];
    final editingId = _editingMsgId;

    _textCtrl.clear();
    setState(() {
      _isSending = true;
      _attachedMediaBase64 = null;
      _attachedMediaType = null;
      _replyingTo = null;
      _editingMsgId = null;
    });

    try {
      if (editingId != null) {
        // Edit mode
        await ApiService().editChatMessage(editingId, text, username: myName);
      } else {
        // Send mode
        final newMsg = await ApiService().sendChatMessage(
          text,
          username: myName,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          replyToId: replyId,
          replyToUsername: replyUser,
          replyToMessage: replyText,
        );
        _messages.add(newMsg);
        AnalyticsService().logSendChatMessage();
      }
      await _loadMessages(initial: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _pickAttachment(ImageSource source, bool isVideo) async {
    try {
      XFile? file;
      if (isVideo) {
        file = await _picker.pickVideo(source: source);
      } else {
        file = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
      }
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final mime = isVideo ? 'video/mp4' : 'image/png';
      final base64Str = 'data:$mime;base64,${base64Encode(bytes)}';

      setState(() {
        _attachedMediaBase64 = base64Str;
        _attachedMediaType = isVideo ? 'video' : 'image';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not attach file: $e')),
      );
    }
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
              leading: const Icon(Icons.photo_camera_rounded, color: Colors.teal),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAttachment(ImageSource.camera, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.blue),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService().deleteChatMessage(msgId, username: _getMyDisplayName());
      _loadMessages(initial: false);
    }
  }

  void _startReply(Map<String, dynamic> msg) {
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
    setState(() {
      _editingMsgId = msg['id'];
      _textCtrl.text = msg['message'] ?? '';
      _replyingTo = null;
    });
  }

  void _sendSticker(String stickerLabel) {
    ApiService().sendChatMessage(
      '',
      username: _getMyDisplayName(),
      mediaUrl: stickerLabel,
      mediaType: 'sticker',
    ).then((_) {
      _loadMessages(initial: false);
    });
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.forum_outlined, color: Colors.teal, size: 22),
                SizedBox(width: 8),
                Text('Live Community Chat'),
              ],
            ),
            Text(
              'Chatting as: $myDisplayName',
              style: const TextStyle(fontSize: 11, color: Colors.teal),
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
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Connected as $myDisplayName · Tap ✏️ to edit or 🗑️ to delete your messages',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.teal.shade900,
                    fontWeight: FontWeight.w500,
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
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Say hi to the community as $myDisplayName!',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final msgId = msg['id'] ?? '';
                          final sender = msg['username'] ?? 'Anonymous';
                          final isMe = myDisplayName.toLowerCase() == sender.toLowerCase() ||
                              sender.toLowerCase() == 'traveler' ||
                              sender.toLowerCase() == 'globetrotter user';
                          final text = msg['message'] ?? '';
                          final mediaUrl = msg['media_url'] ?? '';
                          final mediaType = msg['media_type'] ?? '';
                          final replyUser = msg['reply_to_username'] ?? '';
                          final replyText = msg['reply_to_message'] ?? '';
                          final isEdited = (msg['is_edited'] ?? 0) == 1;
                          final timeStr = _formatTime(msg['created_at'] ?? '');

                          return Padding(
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
                                      sender.isNotEmpty ? sender[0].toUpperCase() : '?',
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
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                    tooltip: 'Delete message',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _deleteMessage(msgId),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                                    tooltip: 'Edit message',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _startEdit(msg),
                                  ),
                                  const SizedBox(width: 6),
                                ],

                                Flexible(
                                  child: GestureDetector(
                                    onLongPress: () => _showMsgActions(msg, isMe),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.surfaceContainerHighest,
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
                                        children: [
                                          // Display Name Header
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Text(
                                              isMe ? myDisplayName : sender,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isMe
                                                    ? theme.colorScheme.onPrimary.withValues(alpha: 0.9)
                                                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                              ),
                                            ),
                                          ),

                                          // Quoted reply block
                                          if (replyUser.isNotEmpty)
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: const Border(
                                                  left: BorderSide(
                                                    color: Colors.tealAccent,
                                                    width: 3,
                                                  ),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                                    style: const TextStyle(fontSize: 11),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),

                                          // Media attachment renderer
                                          if (mediaUrl.isNotEmpty) ...[
                                            _buildMediaBubble(mediaUrl, mediaType),
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
                                                    : theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),

                                          const SizedBox(height: 4),

                                          // Footer time & edited status + Quick reply icon
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isEdited)
                                                Padding(
                                                  padding: const EdgeInsets.only(right: 4),
                                                  child: Text(
                                                    '(edited)',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontStyle: FontStyle.italic,
                                                      color: isMe
                                                          ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                                                          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                                    ),
                                                  ),
                                                ),
                                              Text(
                                                timeStr,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isMe
                                                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                                                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () => _startReply(msg),
                                                child: Icon(
                                                  Icons.reply_rounded,
                                                  size: 14,
                                                  color: isMe
                                                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
                                                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
          if (_replyingTo != null || _editingMsgId != null || _attachedMediaBase64 != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(
                    _editingMsgId != null
                        ? Icons.edit_rounded
                        : _attachedMediaBase64 != null
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
                          : _attachedMediaBase64 != null
                              ? 'Media attached ($_attachedMediaType)'
                              : 'Replying to ${_replyingTo!['username']}: ${_replyingTo!['message']}',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      setState(() {
                        _replyingTo = null;
                        _editingMsgId = null;
                        _attachedMediaBase64 = null;
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
                        icon: Icon(
                          _showEmojiDrawer
                              ? Icons.keyboard_hide_rounded
                              : Icons.emoji_emotions_outlined,
                          color: Colors.amber.shade700,
                        ),
                        onPressed: () {
                          setState(() => _showEmojiDrawer = !_showEmojiDrawer);
                        },
                      ),
                      // Media attachment button
                      IconButton(
                        icon: const Icon(Icons.attach_file_rounded, color: Colors.teal),
                        onPressed: _showAttachmentMenu,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: _editingMsgId != null
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
                        onPressed: _isSending ? null : _sendMessage,
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(_editingMsgId != null ? Icons.check_rounded : Icons.send_rounded),
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
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
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

  Widget _buildMediaBubble(String mediaUrl, String mediaType) {
    if (mediaType == 'sticker') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          mediaUrl,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      );
    }

    if (mediaUrl.startsWith('data:image')) {
      try {
        final base64Data = mediaUrl.split(',').last;
        final bytes = base64Decode(base64Data);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, height: 180, fit: BoxFit.cover),
        );
      } catch (_) {}
    }

    if (mediaType == 'video') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_fill_rounded, color: Colors.purple, size: 28),
            SizedBox(width: 8),
            Text('Video Attachment', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        mediaUrl,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40),
      ),
    );
  }

  Widget _buildEmojiStickerDrawer(ThemeData theme) {
    final emojis = [
      '😊', '😂', '😍', '🔥', '👍', '❤️', '🎉', '🚀', '🇨🇲', '✨',
      '⭐', '🙌', '🤩', '🥳', '👏', '💯', '🌴', '✈️', '🗺️', '📸',
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: emojis.length,
                    itemBuilder: (ctx, i) {
                      return InkWell(
                        onTap: () {
                          _textCtrl.text += emojis[i];
                        },
                        child: Center(
                          child: Text(emojis[i], style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    },
                  ),
                  // Stickers List
                  ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: stickers.length,
                    itemBuilder: (ctx, i) {
                      return ListTile(
                        dense: true,
                        title: Text(stickers[i], style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.send_rounded, size: 16, color: Colors.teal),
                        onTap: () {
                          setState(() => _showEmojiDrawer = false);
                          _sendSticker(stickers[i]);
                        },
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
