import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../data/community_feed_data.dart';
import 'community_comments_sheet.dart';
import 'community_style.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _sort = 'Latest';
  final _likedPostIds = <String>{};
  final _bookmarkedPostIds = <String>{};

  List<CommunityPost> get _posts {
    final posts = [...communityPosts];
    if (_sort == 'Top') {
      posts.sort((a, b) => b.likes.compareTo(a.likes));
    }
    return posts;
  }

  void _toggleLike(String postId) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_likedPostIds.contains(postId)) {
        _likedPostIds.remove(postId);
      } else {
        _likedPostIds.add(postId);
      }
    });
  }

  void _toggleBookmark(String postId) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_bookmarkedPostIds.contains(postId)) {
        _bookmarkedPostIds.remove(postId);
      } else {
        _bookmarkedPostIds.add(postId);
      }
    });
  }

  void _showComposeSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _ComposeSheet(),
    );
  }

  void _openComments(CommunityPost post) {
    HapticFeedback.lightImpact();
    CommunityCommentsSheet.show(context, post);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityColors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _ExploreTopBar(
                  sort: _sort,
                  onSortChanged: (value) => setState(() => _sort = value),
                ),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: _posts.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      thickness: 0.5,
                      color: CommunityColors.border,
                    ),
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return _FeedPost(
                        post: post,
                        isLiked: _likedPostIds.contains(post.id),
                        isBookmarked: _bookmarkedPostIds.contains(post.id),
                        onLike: () => _toggleLike(post.id),
                        onBookmark: () => _toggleBookmark(post.id),
                        onComments: () => _openComments(post),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 96,
              child: _ComposeFab(onTap: _showComposeSheet),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreTopBar extends StatelessWidget {
  const _ExploreTopBar({
    required this.sort,
    required this.onSortChanged,
  });

  final String sort;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CommunityColors.bg,
        border: Border(
          bottom: BorderSide(color: CommunityColors.border, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 10),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(
              Icons.chevron_left,
              color: CommunityColors.textPrimary,
              size: 22,
            ),
            label: Text(
              'Home',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: CommunityColors.textPrimary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
          Expanded(
            child: Text(
              'Explore',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CommunityColors.textPrimary,
              ),
            ),
          ),
          PopupMenuButton<String>(
            initialValue: sort,
            color: CommunityColors.pillBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            offset: const Offset(0, 36),
            onSelected: onSortChanged,
            itemBuilder: (context) => ['Latest', 'Top', 'Following']
                .map(
                  (label) => PopupMenuItem<String>(
                    value: label,
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: CommunityColors.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: CommunityColors.pillBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CommunityColors.border, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sort,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CommunityColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: CommunityColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedPost extends StatelessWidget {
  const _FeedPost({
    required this.post,
    required this.isLiked,
    required this.isBookmarked,
    required this.onLike,
    required this.onBookmark,
    required this.onComments,
  });

  final CommunityPost post;
  final bool isLiked;
  final bool isBookmarked;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final likeCount = post.likes + (isLiked ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AuthorAvatar(
                initials: post.authorInitials,
                color: post.avatarColor ?? CommunityColors.pillBg,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.authorName,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: CommunityColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (post.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            size: 15,
                            color: CommunityColors.verified,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          post.timeAgo,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: CommunityColors.textSecondary,
                          ),
                        ),
                        if (post.distance != null) ...[
                          Text(
                            ' · ',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: CommunityColors.textSecondary,
                            ),
                          ),
                          const Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: CommunityColors.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            post.distance!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: CommunityColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.more_horiz,
                  color: CommunityColors.textSecondary,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.content,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.45,
              color: CommunityColors.textPrimary,
            ),
          ),
          if (post.media != null) ...[
            const SizedBox(height: 12),
            _PostMediaCard(media: post.media!),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _ActionIcon(
                icon: isLiked ? LucideIcons.heart : LucideIcons.heart,
                filled: isLiked,
                count: likeCount > 0 ? formatCount(likeCount) : '0',
                activeColor: isLiked ? const Color(0xFFFF3040) : null,
                onTap: onLike,
              ),
              const SizedBox(width: 18),
              _ActionIcon(
                icon: LucideIcons.messageCircle,
                count: formatCount(post.replies),
                onTap: onComments,
              ),
              const SizedBox(width: 18),
              _ActionIcon(
                icon: LucideIcons.repeat2,
                count: post.reposts > 0 ? formatCount(post.reposts) : null,
                onTap: () => HapticFeedback.lightImpact(),
              ),
              const SizedBox(width: 18),
              _ActionIcon(
                icon: LucideIcons.share,
                onTap: () => HapticFeedback.lightImpact(),
              ),
              const Spacer(),
              _ActionIcon(
                icon: isBookmarked ? LucideIcons.bookmark : LucideIcons.bookmark,
                filled: isBookmarked,
                onTap: onBookmark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostMediaCard extends StatelessWidget {
  const _PostMediaCard({required this.media});

  final CommunityPostMedia media;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 280,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CommunityColors.surface,
              media.accent.withValues(alpha: 0.25),
              CommunityColors.bg,
            ],
          ),
          border: Border.all(color: CommunityColors.border, width: 0.5),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                media.icon,
                size: 140,
                color: media.accent.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: media.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: media.accent.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      media.title,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: media.accent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    media.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: CommunityColors.textPrimary,
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

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({
    required this.initials,
    required this.color,
  });

  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            Color.lerp(color, Colors.black, 0.35)!,
          ],
        ),
        border: Border.all(color: CommunityColors.border, width: 0.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: CommunityColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.onTap,
    this.count,
    this.filled = false,
    this.activeColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? count;
  final bool filled;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? CommunityColors.iconMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: color,
            fill: filled ? 1.0 : 0.0,
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text(
              count!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: CommunityColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposeFab extends StatelessWidget {
  const _ComposeFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: CommunityColors.fabPink,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x66FF0069),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          LucideIcons.edit3,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

class _ComposeSheet extends StatelessWidget {
  const _ComposeSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: CommunityColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.fromBorderSide(
          BorderSide(color: CommunityColors.border, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 18),
          Text(
            'New thread',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: CommunityColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            minLines: 4,
            maxLines: 8,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: CommunityColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Share a battle result, ask for help, or post a prediction…',
              hintStyle: GoogleFonts.inter(
                fontSize: 15,
                color: CommunityColors.textSecondary,
              ),
              filled: true,
              fillColor: CommunityColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: CommunityColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: CommunityColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: CommunityColors.border),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: CommunityColors.fabPink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Post',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
