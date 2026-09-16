import 'package:flutter/material.dart';

enum CommunityPostType { help, win, event, vibe }

class CommunityStory {
  const CommunityStory({
    required this.name,
    required this.initials,
    this.hasUnseen = false,
    this.isLive = false,
  });

  final String name;
  final String initials;
  final bool hasUnseen;
  final bool isLive;
}

class CommunityPostMedia {
  const CommunityPostMedia({
    required this.title,
    required this.subtitle,
    required this.accent,
    this.icon = Icons.emoji_events_outlined,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorInitials,
    required this.grade,
    required this.subject,
    required this.content,
    required this.timeAgo,
    required this.likes,
    required this.replies,
    required this.type,
    this.topComment,
    this.isVerified = false,
    this.distance,
    this.reposts = 0,
    this.media,
    this.avatarColor,
  });

  final String id;
  final String authorName;
  final String authorInitials;
  final String grade;
  final String subject;
  final String content;
  final String timeAgo;
  final int likes;
  final int replies;
  final CommunityPostType type;
  final String? topComment;
  final bool isVerified;
  final String? distance;
  final int reposts;
  final CommunityPostMedia? media;
  final Color? avatarColor;
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorName,
    required this.authorInitials,
    required this.content,
    required this.timeAgo,
    this.likes = 0,
    this.isAuthor = false,
  });

  final String id;
  final String postId;
  final String authorName;
  final String authorInitials;
  final String content;
  final String timeAgo;
  final int likes;
  final bool isAuthor;
}

const postCommentsById = <String, List<CommunityComment>>{
  'post-1': [
    CommunityComment(
      id: 'c1-1',
      postId: 'post-1',
      authorName: 'Daniel M.',
      authorInitials: 'DM',
      content:
          'Combination = order doesn\'t matter. Permutation = order matters!',
      timeAgo: '1h',
      likes: 14,
    ),
    CommunityComment(
      id: 'c1-2',
      postId: 'post-1',
      authorName: 'Meron A.',
      authorInitials: 'MA',
      content: 'n! / r!(n-r)! for combinations — write it on your formula sheet',
      timeAgo: '45m',
      likes: 8,
    ),
    CommunityComment(
      id: 'c1-3',
      postId: 'post-1',
      authorName: 'Selam Tadesse',
      authorInitials: 'ST',
      content: 'This cleared it up, thanks squad 🙌',
      timeAgo: '30m',
      likes: 5,
      isAuthor: true,
    ),
    CommunityComment(
      id: 'c1-4',
      postId: 'post-1',
      authorName: 'Yosef K.',
      authorInitials: 'YK',
      content: 'Exam Friday too — we should do a quick review call',
      timeAgo: '20m',
      likes: 3,
    ),
  ],
  'post-2': [
    CommunityComment(
      id: 'c2-1',
      postId: 'post-2',
      authorName: 'Hanna B.',
      authorInitials: 'HB',
      content: 'W Daniel!! teach us your ways',
      timeAgo: '3h',
      likes: 21,
    ),
    CommunityComment(
      id: 'c2-2',
      postId: 'post-2',
      authorName: 'Tigist H.',
      authorInitials: 'TH',
      content: '94% is insane, congrats',
      timeAgo: '2h',
      likes: 6,
    ),
  ],
  'post-3': [
    CommunityComment(
      id: 'c3-1',
      postId: 'post-3',
      authorName: 'Ruth N.',
      authorInitials: 'RN',
      content: '👋👋 count me in',
      timeAgo: '5h',
      likes: 11,
    ),
    CommunityComment(
      id: 'c3-2',
      postId: 'post-3',
      authorName: 'Daniel M.',
      authorInitials: 'DM',
      content: 'I\'ll bring practice problems',
      timeAgo: '4h',
      likes: 7,
    ),
    CommunityComment(
      id: 'c3-3',
      postId: 'post-3',
      authorName: 'Abenezer L.',
      authorInitials: 'AL',
      content: 'Can\'t make 3 PM but down for Sunday',
      timeAgo: '3h',
      likes: 4,
    ),
  ],
  'post-4': [
    CommunityComment(
      id: 'c4-1',
      postId: 'post-4',
      authorName: 'Daniel M.',
      authorInitials: 'DM',
      content: 'felt this in my soul',
      timeAgo: '7h',
      likes: 42,
    ),
    CommunityComment(
      id: 'c4-2',
      postId: 'post-4',
      authorName: 'Hanna B.',
      authorInitials: 'HB',
      content: '"just one more chapter" → 2 AM every time',
      timeAgo: '6h',
      likes: 28,
    ),
    CommunityComment(
      id: 'c4-3',
      postId: 'post-4',
      authorName: 'Meron A.',
      authorInitials: 'MA',
      content: 'Netflix said are you still watching and I took it personally',
      timeAgo: '5h',
      likes: 19,
    ),
  ],
  'post-5': [
    CommunityComment(
      id: 'c5-1',
      postId: 'post-5',
      authorName: 'Tigist H.',
      authorInitials: 'TH',
      content: 'Needed this today 🙏',
      timeAgo: '10h',
      likes: 18,
    ),
    CommunityComment(
      id: 'c5-2',
      postId: 'post-5',
      authorName: 'Selam Tadesse',
      authorInitials: 'ST',
      content: '28 days is legendary, keep going',
      timeAgo: '9h',
      likes: 12,
    ),
  ],
  'post-6': [
    CommunityComment(
      id: 'c6-1',
      postId: 'post-6',
      authorName: 'Abenezer L.',
      authorInitials: 'AL',
      content: 'Draw the diagram first — split horizontal vs vertical motion',
      timeAgo: '20h',
      likes: 9,
    ),
    CommunityComment(
      id: 'c6-2',
      postId: 'post-6',
      authorName: 'Hanna B.',
      authorInitials: 'HB',
      content: 'Hint: time of flight is the same for both directions',
      timeAgo: '18h',
      likes: 6,
    ),
  ],
};

List<CommunityComment> commentsForPost(String postId) {
  return postCommentsById[postId] ?? const [];
}

const communityStories = [
  CommunityStory(name: 'You', initials: 'ST', hasUnseen: false),
  CommunityStory(name: 'Hanna', initials: 'HB', hasUnseen: true),
  CommunityStory(name: 'Daniel', initials: 'DM', hasUnseen: true, isLive: true),
  CommunityStory(name: 'Meron', initials: 'MA', hasUnseen: false),
  CommunityStory(name: 'Tigist', initials: 'TH', hasUnseen: true),
  CommunityStory(name: 'Abenezer', initials: 'AL', hasUnseen: false),
  CommunityStory(name: 'Ruth', initials: 'RN', hasUnseen: true),
];

const communityPosts = [
  CommunityPost(
    id: 'post-2',
    authorName: 'Daniel M.',
    authorInitials: 'DM',
    grade: 'Gr 10',
    subject: 'Physics',
    content:
        '1v1 battle win vs Hanna — optics round destroyed me last week, not today 🔥',
    likes: 0,
    replies: 1,
    reposts: 3,
    timeAgo: '1 hr. ago',
    distance: '12 km',
    type: CommunityPostType.win,
    isVerified: true,
    avatarColor: Color(0xFF5C6BC0),
    media: CommunityPostMedia(
      title: 'BATTLE RESULT',
      subtitle: 'Daniel 8 — 5 Hanna · Physics · 10 rounds',
      accent: Color(0xFFFF5C39),
      icon: Icons.sports_esports_outlined,
    ),
  ),
  CommunityPost(
    id: 'post-1',
    authorName: 'Hanna B.',
    authorInitials: 'HB',
    grade: 'Gr 10',
    subject: 'Mathematics',
    content:
        'Can someone explain permutation vs combination before Friday\'s exam? 😭',
    likes: 48,
    replies: 12,
    reposts: 6,
    timeAgo: '2 hr. ago',
    distance: '8 km',
    type: CommunityPostType.help,
    isVerified: true,
    avatarColor: Color(0xFFEC407A),
  ),
  CommunityPost(
    id: 'post-3',
    authorName: 'Amina T.',
    authorInitials: 'AT',
    grade: 'Gr 11',
    subject: 'Chemistry',
    content:
        'Organic chem study group Saturday 3 PM at Bole library. Drop a 👋 if you\'re in!',
    likes: 67,
    replies: 23,
    reposts: 11,
    timeAgo: '6 hr. ago',
    distance: '24 km',
    type: CommunityPostType.event,
    avatarColor: Color(0xFF26A69A),
    media: CommunityPostMedia(
      title: 'STUDY MEETUP',
      subtitle: 'Saturday · 3:00 PM · Bole Library',
      accent: Color(0xFF00C896),
      icon: Icons.groups_outlined,
    ),
  ),
  CommunityPost(
    id: 'post-4',
    authorName: 'Tigist H.',
    authorInitials: 'TH',
    grade: 'Gr 9',
    subject: 'English',
    content:
        'POV: you said "just one more chapter" and now it\'s 1 AM 📚',
    likes: 203,
    replies: 31,
    reposts: 42,
    timeAgo: '8 hr. ago',
    distance: '31 km',
    type: CommunityPostType.vibe,
    avatarColor: Color(0xFFAB47BC),
  ),
  CommunityPost(
    id: 'post-5',
    authorName: 'Abenezer L.',
    authorInitials: 'AL',
    grade: 'Gr 12',
    subject: 'Matric',
    content:
        '28-day streak. Matric in 3 months. If I failed term 1 and bounced back, you can too.',
    likes: 156,
    replies: 18,
    reposts: 28,
    timeAgo: '12 hr. ago',
    distance: '45 km',
    type: CommunityPostType.win,
    isVerified: true,
    avatarColor: Color(0xFFFFA726),
    media: CommunityPostMedia(
      title: 'STREAK MILESTONE',
      subtitle: '28 days · Matric prep · Grade 12',
      accent: Color(0xFFF5A623),
      icon: Icons.local_fire_department_outlined,
    ),
  ),
  CommunityPost(
    id: 'post-6',
    authorName: 'Yosef K.',
    authorInitials: 'YK',
    grade: 'Gr 11',
    subject: 'Physics',
    content:
        'Stuck on projectile motion Q4. Hints only please — no full answers 🙏',
    likes: 22,
    replies: 9,
    reposts: 1,
    timeAgo: '1d',
    distance: '19 km',
    type: CommunityPostType.help,
    avatarColor: Color(0xFF42A5F5),
  ),
];

Color communitySubjectColor(String subject) {
  switch (subject.toLowerCase()) {
    case 'mathematics':
      return const Color(0xFF6C63FF);
    case 'physics':
      return const Color(0xFF378ADD);
    case 'chemistry':
      return const Color(0xFF00C896);
    case 'english':
      return const Color(0xFFF5A623);
    case 'matric':
      return const Color(0xFFFF6B6B);
    default:
      return const Color(0xFFA89EFF);
  }
}

String communityTypeLabel(CommunityPostType type) {
  switch (type) {
    case CommunityPostType.help:
      return 'Need help';
    case CommunityPostType.win:
      return 'Study win';
    case CommunityPostType.event:
      return 'Study meetup';
    case CommunityPostType.vibe:
      return 'Relatable';
  }
}

IconData communityTypeIcon(CommunityPostType type) {
  switch (type) {
    case CommunityPostType.help:
      return Icons.help_outline_rounded;
    case CommunityPostType.win:
      return Icons.emoji_events_outlined;
    case CommunityPostType.event:
      return Icons.event_outlined;
    case CommunityPostType.vibe:
      return Icons.mood_outlined;
  }
}

List<CommunityPost> communityPostsForFilter(String filter) {
  if (filter == 'all') return communityPosts;
  if (filter == 'help') {
    return communityPosts
        .where((p) => p.type == CommunityPostType.help)
        .toList();
  }
  if (filter == 'wins') {
    return communityPosts
        .where((p) => p.type == CommunityPostType.win)
        .toList();
  }
  if (filter == 'events') {
    return communityPosts
        .where((p) =>
            p.type == CommunityPostType.event ||
            p.type == CommunityPostType.vibe)
        .toList();
  }
  return communityPosts;
}

String formatCount(int count) {
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}k';
  }
  return '$count';
}
