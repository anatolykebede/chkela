import 'map_students.dart';

class StudentMood {
  const StudentMood({
    required this.emoji,
    required this.label,
  });

  final String emoji;
  final String label;
}

class ProfileComment {
  const ProfileComment({
    required this.authorName,
    required this.authorInitials,
    required this.text,
    required this.timeAgo,
  });

  final String authorName;
  final String authorInitials;
  final String text;
  final String timeAgo;
}

const _currentUserId = 'selam-tadesse';

const studentMoods = <String, StudentMood>{
  'hanna-b': StudentMood(emoji: '📚', label: 'Deep focus mode'),
  'daniel-m': StudentMood(emoji: '☕', label: 'Library grind'),
  'meron-a': StudentMood(emoji: '📝', label: 'Exam prep'),
  'selam-tadesse': StudentMood(emoji: '🎯', label: 'Building habits'),
  'yosef-k': StudentMood(emoji: '⚡', label: 'Physics problems'),
  'tigist-h': StudentMood(emoji: '🌱', label: 'Learning algebra'),
  'abenezer-l': StudentMood(emoji: '🏆', label: 'Matric countdown'),
  'ruth-n': StudentMood(emoji: '📖', label: 'Reading notes'),
};

const studentFriendIds = <String, List<String>>{
  'hanna-b': ['daniel-m', 'meron-a', 'abenezer-l', 'selam-tadesse', 'tigist-h'],
  'daniel-m': ['hanna-b', 'meron-a', 'ruth-n', 'selam-tadesse'],
  'meron-a': ['hanna-b', 'daniel-m', 'yosef-k', 'selam-tadesse'],
  'selam-tadesse': ['hanna-b', 'daniel-m', 'meron-a', 'tigist-h', 'ruth-n'],
  'yosef-k': ['meron-a', 'abenezer-l', 'tigist-h'],
  'tigist-h': ['selam-tadesse', 'hanna-b', 'yosef-k', 'ruth-n'],
  'abenezer-l': ['hanna-b', 'yosef-k', 'daniel-m'],
  'ruth-n': ['daniel-m', 'selam-tadesse', 'tigist-h'],
};

const studentComments = <String, List<ProfileComment>>{
  'hanna-b': [
    ProfileComment(
      authorName: 'Daniel M.',
      authorInitials: 'DM',
      text: 'Thanks for explaining quadratic graphs — saved my week!',
      timeAgo: '2h ago',
    ),
    ProfileComment(
      authorName: 'Selam Tadesse',
      authorInitials: 'ST',
      text: 'Study session tomorrow? Same spot at Bole.',
      timeAgo: '1d ago',
    ),
  ],
  'daniel-m': [
    ProfileComment(
      authorName: 'Hanna B.',
      authorInitials: 'HB',
      text: 'Your chem notes are always so clear.',
      timeAgo: '5h ago',
    ),
  ],
  'meron-a': [
    ProfileComment(
      authorName: 'Yosef K.',
      authorInitials: 'YK',
      text: 'That physics recap was exactly what I needed.',
      timeAgo: '3h ago',
    ),
    ProfileComment(
      authorName: 'Selam Tadesse',
      authorInitials: 'ST',
      text: 'Let\'s do a group quiz this weekend.',
      timeAgo: '2d ago',
    ),
  ],
  'selam-tadesse': [
    ProfileComment(
      authorName: 'Hanna B.',
      authorInitials: 'HB',
      text: 'Proud of your streak — keep going!',
      timeAgo: '4h ago',
    ),
    ProfileComment(
      authorName: 'Tigist H.',
      authorInitials: 'TH',
      text: 'Thanks for helping me with algebra.',
      timeAgo: '1d ago',
    ),
  ],
  'yosef-k': [
    ProfileComment(
      authorName: 'Abenezer L.',
      authorInitials: 'AL',
      text: 'Solid problem sets as always.',
      timeAgo: '6h ago',
    ),
  ],
  'tigist-h': [
    ProfileComment(
      authorName: 'Ruth N.',
      authorInitials: 'RN',
      text: 'Welcome to Chkela — you\'re picking things up fast!',
      timeAgo: '8h ago',
    ),
  ],
  'abenezer-l': [
    ProfileComment(
      authorName: 'Hanna B.',
      authorInitials: 'HB',
      text: 'Matric prep goals — you\'ve got this.',
      timeAgo: '12h ago',
    ),
    ProfileComment(
      authorName: 'Daniel M.',
      authorInitials: 'DM',
      text: 'Share your revision timetable when you can.',
      timeAgo: '2d ago',
    ),
  ],
  'ruth-n': [
    ProfileComment(
      authorName: 'Daniel M.',
      authorInitials: 'DM',
      text: 'Great progress on the bio chapter!',
      timeAgo: '1d ago',
    ),
  ],
};

StudentMood moodForStudent(MapStudent student) {
  return studentMoods[student.id] ??
      const StudentMood(emoji: '✨', label: 'Ready to learn');
}

List<MapStudent> friendsForStudent(MapStudent student) {
  final ids = studentFriendIds[student.id] ?? const [];
  return [
    for (final id in ids)
      if (mapStudentById(id) != null) mapStudentById(id)!,
  ];
}

List<MapStudent> mutualFriendsWithCurrentUser(MapStudent student) {
  if (student.isCurrentUser) return const [];

  final viewerFriends = studentFriendIds[_currentUserId] ?? const [];
  final theirFriends = studentFriendIds[student.id] ?? const [];
  final mutualIds = viewerFriends.toSet().intersection(theirFriends.toSet());

  return [
    for (final id in mutualIds)
      if (mapStudentById(id) != null) mapStudentById(id)!,
  ];
}

List<ProfileComment> commentsForStudent(MapStudent student) {
  return studentComments[student.id] ?? const [];
}

String defaultBioFor(MapStudent student) {
  return student.bio ?? 'Chkela student · ${student.grade} · ${student.school}';
}

bool isFriendOfCurrentUser(MapStudent student) {
  if (student.isCurrentUser) return false;
  final viewerFriends = studentFriendIds[_currentUserId] ?? const [];
  return viewerFriends.contains(student.id);
}
