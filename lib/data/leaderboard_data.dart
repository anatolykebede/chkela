import 'leaderboard_api.dart';
import 'path_progress_store.dart';
import 'study_progress_store.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.initials,
    required this.grade,
    required this.points,
    this.isCurrentUser = false,
    this.phone,
  });

  final int rank;
  final String name;
  final String initials;
  final String grade;
  final int points;
  final bool isCurrentUser;
  final String? phone;
}

/// Same formula as profile points so Home / Profile / Leaderboard stay aligned.
int computeLeaderboardPoints(
  PathProgressStore path,
  StudyProgressStore study,
) {
  return path.xpWallet +
      (path.totalStars * 40) +
      study.notesCompleted * 35 +
      study.decksCompleted * 45 +
      study.chapterExamsCompleted * 80;
}

String leaderboardDisplayName(String? fullName) {
  final raw = fullName?.trim() ?? '';
  if (raw.isEmpty) return 'You';
  final first = raw.split(RegExp(r'\s+')).firstWhere(
        (part) => part.isNotEmpty,
        orElse: () => 'You',
      );
  if (first.length <= 15) return first;
  return first.substring(0, 15);
}

String leaderboardInitials(String? fullName) {
  final parts = (fullName ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'YO';
  if (parts.length == 1) {
    final w = parts.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String formatLeaderboardPoints(int points) {
  if (points >= 1000) {
    return '${points ~/ 1000},${(points % 1000).toString().padLeft(3, '0')}';
  }
  return '$points';
}

/// Merge server classmates with the signed-in student's live points.
List<LeaderboardEntry> mergeLeaderboard({
  required String? phoneE164,
  required String? fullName,
  required String? grade,
  required List<RemoteLeaderboardEntry> remote,
  PathProgressStore? path,
  StudyProgressStore? study,
}) {
  final pathStore = path ?? PathProgressStore.instance;
  final studyStore = study ?? StudyProgressStore.instance;
  final myPoints = computeLeaderboardPoints(pathStore, studyStore);
  final displayGrade =
      (grade != null && grade.trim().isNotEmpty) ? grade.trim() : 'Your grade';
  final myPhone = phoneE164?.trim();
  final myFullName = fullName?.trim();

  final rows = <({String? phone, String name, String initials, int points, bool me})>[];

  for (final entry in remote) {
    if (myPhone != null &&
        myPhone.isNotEmpty &&
        entry.phone == myPhone) {
      continue;
    }
    rows.add((
      phone: entry.phone,
      name: leaderboardDisplayName(entry.name),
      initials: leaderboardInitials(entry.name),
      points: entry.points,
      me: false,
    ));
  }

  rows.add((
    phone: myPhone,
    name: leaderboardDisplayName(myFullName),
    initials: leaderboardInitials(myFullName),
    points: myPoints,
    me: true,
  ));

  rows.sort((a, b) {
    final byPoints = b.points.compareTo(a.points);
    if (byPoints != 0) return byPoints;
    if (a.me != b.me) return a.me ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return [
    for (var i = 0; i < rows.length; i++)
      LeaderboardEntry(
        rank: i + 1,
        name: rows[i].name,
        initials: rows[i].initials,
        grade: displayGrade,
        points: rows[i].points,
        isCurrentUser: rows[i].me,
        phone: rows[i].phone,
      ),
  ];
}

/// Offline / pre-sync fallback: signed-in student only.
List<LeaderboardEntry> buildLocalLeaderboard({
  required String? fullName,
  required String? grade,
  PathProgressStore? path,
  StudyProgressStore? study,
}) {
  return mergeLeaderboard(
    phoneE164: null,
    fullName: fullName,
    grade: grade,
    remote: const [],
    path: path,
    study: study,
  );
}
