import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/community_feed_data.dart';
import 'community_style.dart';

class CommunityCommentsSheet extends StatefulWidget {
  const CommunityCommentsSheet({
    super.key,
    required this.post,
  });

  final CommunityPost post;

  static Future<void> show(BuildContext context, CommunityPost post) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CommunityCommentsSheet(post: post),
    );
  }

  @override
  State<CommunityCommentsSheet> createState() => _CommunityCommentsSheetState();
}

class _CommunityCommentsSheetState extends State<CommunityCommentsSheet> {
  final _controller = TextEditingController();
  final _likedCommentIds = <String>{};
  late List<CommunityComment> _comments;

  CommunityPost get post => widget.post;

  @override
  void initState() {
    super.initState();
    _comments = [...commentsForPost(post.id)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCommentLike(String commentId) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_likedCommentIds.contains(commentId)) {
        _likedCommentIds.remove(commentId);
      } else {
        _likedCommentIds.add(commentId);
      }
    });
  }

  void _sendComment() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      _comments.add(
        CommunityComment(
          id: 'local-${DateTime.now().millisecondsSinceEpoch}',
          postId: post.id,
          authorName: 'Selam Tadesse',
          authorInitials: 'ST',
          content: text,
          timeAgo: 'Just now',
          isAuthor: true,
        ),
      );
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        bottom: viewInsets.bottom,
      ),
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: CommunityColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.fromBorderSide(
            BorderSide(color: CommunityColors.border, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: CommunityColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: CommunityColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Comments · ${post.replies + (_comments.length - commentsForPost(post.id).length)}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CommunityColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _PostPreview(post: post),
            ),
            const Divider(height: 1, color: CommunityColors.border),
            Expanded(
              child: _comments.isEmpty
                  ? Center(
                      child: Text(
                        'No comments yet — start the convo',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: CommunityColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      itemCount: _comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return _CommentTile(
                          comment: comment,
                          isLiked: _likedCommentIds.contains(comment.id),
                          onLike: () => _toggleCommentLike(comment.id),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: CommunityColors.bg,
                border: Border(
                  top: BorderSide(color: CommunityColors.border, width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _AuthorAvatar(initials: 'ST'),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: CommunityColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add a comment…',
                          hintStyle: GoogleFonts.inter(
                            color: CommunityColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: CommunityColors.pillBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: CommunityColors.border,
                              width: 0.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: CommunityColors.border,
                              width: 0.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: CommunityColors.textSecondary,
                              width: 0.5,
                            ),
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendComment,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: CommunityColors.fabPink,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostPreview extends StatelessWidget {
  const _PostPreview({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CommunityColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CommunityColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorAvatar(initials: post.authorInitials),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.authorName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CommunityColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  post.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: CommunityColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.isLiked,
    required this.onLike,
  });

  final CommunityComment comment;
  final bool isLiked;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AuthorAvatar(initials: comment.authorInitials),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                decoration: BoxDecoration(
                  color: comment.isAuthor
                      ? CommunityColors.pillBg
                      : CommunityColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CommunityColors.border,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.authorName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: CommunityColors.textPrimary,
                          ),
                        ),
                        if (comment.isAuthor) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· you',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: CommunityColors.fabPink,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.content,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: CommunityColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    comment.timeAgo,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: CommunityColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: onLike,
                    child: Row(
                      children: [
                        Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 14,
                          color: isLiked
                              ? const Color(0xFFFF3040)
                              : CommunityColors.textSecondary,
                        ),
                        if (comment.likes + (isLiked ? 1 : 0) > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            formatCount(
                              comment.likes + (isLiked ? 1 : 0),
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isLiked
                                  ? const Color(0xFFFF3040)
                                  : CommunityColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Reply',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: CommunityColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: CommunityColors.pillBg,
        shape: BoxShape.circle,
        border: Border.all(
          color: CommunityColors.border,
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: CommunityColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
