import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';

class CommentSection extends StatefulWidget {
  final String destinationId;

  const CommentSection({super.key, required this.destinationId});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final _commentController = TextEditingController();
  final _replyController = TextEditingController();
  final _editController = TextEditingController();

  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;
  bool _isSubmittingReply = false;
  bool _isSubmittingEdit = false;
  String? _error;

  String? _replyingToId;
  String? _replyingToUsername;
  String? _editingCommentId;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final result = await ApiService().getComments(widget.destinationId);
      if (mounted) {
        setState(() {
          _comments = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load comments';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (!AuthProvider().isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to leave a comment')),
      );
      return;
    }

    try {
      setState(() => _isPosting = true);
      final newComment = await ApiService().postComment(widget.destinationId, text);
      _commentController.clear();
      if (mounted) {
        setState(() {
          _comments.add(newComment);
          _isPosting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _submitReply(String parentId) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    if (!AuthProvider().isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to reply')),
      );
      return;
    }

    try {
      setState(() => _isSubmittingReply = true);
      final newReply = await ApiService().postComment(
        widget.destinationId,
        text,
        parentId: parentId,
      );
      _replyController.clear();
      if (mounted) {
        setState(() {
          _comments.add(newReply);
          _replyingToId = null;
          _replyingToUsername = null;
          _isSubmittingReply = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply posted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingReply = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error replying: $e')),
        );
      }
    }
  }

  Future<void> _saveEdit(String commentId) async {
    final text = _editController.text.trim();
    if (text.isEmpty) return;

    try {
      setState(() => _isSubmittingEdit = true);
      final updated = await ApiService().updateComment(
        widget.destinationId,
        commentId,
        text,
      );
      if (mounted) {
        setState(() {
          final idx = _comments.indexWhere((c) => c['id'] == commentId);
          if (idx != -1) {
            _comments[idx] = {
              ..._comments[idx],
              'text': updated['text'] ?? text,
              'updated_at': updated['updated_at'],
            };
          }
          _editingCommentId = null;
          _editController.clear();
          _isSubmittingEdit = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingEdit = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating comment: $e')),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().deleteComment(widget.destinationId, commentId);
      if (mounted) {
        setState(() {
          // Remove comment and any replies referencing it as parent
          _comments.removeWhere((c) => c['id'] == commentId || c['parent_id'] == commentId);
          if (_replyingToId == commentId) {
            _replyingToId = null;
            _replyingToUsername = null;
          }
          if (_editingCommentId == commentId) {
            _editingCommentId = null;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting comment: $e')),
        );
      }
    }
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '';
    try {
      final dt = DateTime.parse(dateVal.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateVal.toString().split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = AuthProvider().username ?? '';

    // Separate top-level comments and child replies
    final commentIds = _comments.map((c) => c['id']?.toString()).toSet();
    final topLevel = _comments.where((c) {
      final pId = c['parent_id']?.toString();
      return pId == null || pId.isEmpty || !commentIds.contains(pId);
    }).toList();

    // Map replies by parent id
    final Map<String, List<Map<String, dynamic>>> repliesByParent = {};
    for (final c in _comments) {
      final pId = c['parent_id']?.toString();
      if (pId != null && pId.isNotEmpty && commentIds.contains(pId)) {
        repliesByParent.putIfAbsent(pId, () => []).add(c);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.forum_rounded, size: 22),
            const SizedBox(width: 8),
            Text(
              'Community Discussion (${_comments.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Comment Input Field
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _postComment(),
                  decoration: const InputDecoration(
                    hintText: 'Share a tip or ask a question...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              _isPosting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
                      onPressed: _postComment,
                      tooltip: 'Post Comment',
                    ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Comments List
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_error != null)
          Center(
            child: TextButton.icon(
              onPressed: _loadComments,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_error!),
            ),
          )
        else if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No comments yet. Be the first to share your experience or ask a question!',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topLevel.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final root = topLevel[index];
              final rootId = root['id']?.toString() ?? '';
              final replies = repliesByParent[rootId] ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCommentCard(root, currentUser, isReply: false),
                  if (replies.isNotEmpty || _replyingToId == rootId)
                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: theme.colorScheme.primary.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final rep in replies) ...[
                              const SizedBox(height: 8),
                              _buildCommentCard(rep, currentUser, isReply: true, rootParentId: rootId),
                            ],
                            if (_replyingToId == rootId) ...[
                              const SizedBox(height: 8),
                              _buildReplyInputBox(rootId),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildReplyInputBox(String parentId) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.reply_rounded, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                'Replying to ${_replyingToUsername != null ? '@$_replyingToUsername' : 'comment'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Cancel Reply',
                onPressed: () {
                  setState(() {
                    _replyingToId = null;
                    _replyingToUsername = null;
                    _replyController.clear();
                  });
                },
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  maxLines: null,
                  autofocus: true,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitReply(parentId),
                  decoration: const InputDecoration(
                    hintText: 'Write a reply...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              _isSubmittingReply
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: Icon(Icons.send_rounded, size: 18, color: theme.colorScheme.primary),
                      onPressed: () => _submitReply(parentId),
                      tooltip: 'Send Reply',
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(
    Map<String, dynamic> c,
    String currentUser, {
    required bool isReply,
    String? rootParentId,
  }) {
    final theme = Theme.of(context);
    final commentId = c['id']?.toString() ?? '';
    final isOwn = c['username'] == currentUser;
    final isEditing = _editingCommentId == commentId;
    final dateStr = _formatDate(c['created_at']);
    final isEdited = c['updated_at'] != null && c['updated_at'].toString().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReply
            ? theme.cardColor.withValues(alpha: 0.8)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isReply ? 0.2 : 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: isReply ? 12 : 14,
                    backgroundColor: isReply
                        ? theme.colorScheme.secondaryContainer
                        : theme.colorScheme.primaryContainer,
                    child: Text(
                      (c['username'] as String? ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: isReply ? 11 : 12,
                        fontWeight: FontWeight.bold,
                        color: isReply
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    c['username'] ?? 'Anonymous',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isReply ? 12 : 13,
                    ),
                  ),
                  if (isOwn) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'You',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  Text(
                    dateStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.disabledColor,
                      fontSize: 11,
                    ),
                  ),
                  if (isEdited) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(edited)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.disabledColor,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Content or Editing mode
          if (isEditing) ...[
            TextField(
              controller: _editController,
              maxLines: null,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _editingCommentId = null;
                      _editController.clear();
                    });
                  },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 6),
                _isSubmittingEdit
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton(
                        onPressed: () => _saveEdit(commentId),
                        child: const Text('Save'),
                      ),
              ],
            ),
          ] else ...[
            Text(
              c['text'] ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: isReply ? 13 : 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),

            // Actions row: Reply, Edit, Delete
            Row(
              children: [
                // Reply button
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    setState(() {
                      // Target the root thread parent so replies stay in that thread
                      _replyingToId = rootParentId ?? commentId;
                      _replyingToUsername = c['username'] ?? 'User';
                      _editingCommentId = null;
                      _replyController.clear();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.reply_rounded, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOwn) ...[
                  const SizedBox(width: 12),
                  // Edit button
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      setState(() {
                        _editingCommentId = commentId;
                        _editController.text = c['text'] ?? '';
                        _replyingToId = null;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Delete button
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _deleteComment(commentId),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                          SizedBox(width: 4),
                          Text(
                            'Delete',
                            style: TextStyle(fontSize: 12, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

