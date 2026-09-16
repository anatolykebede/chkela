import 'package:flutter/material.dart';

enum BattleMode { duel, group, national, school }

class BattleModeInfo {
  const BattleModeInfo({
    required this.mode,
    required this.title,
    required this.subtitle,
    this.isDefault = false,
  });

  final BattleMode mode;
  final String title;
  final String subtitle;
  final bool isDefault;
}

class BattleQuestion {
  const BattleQuestion({
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

const battleModes = [
  BattleModeInfo(
    mode: BattleMode.duel,
    title: '1v1 Duel',
    subtitle: 'Challenge a friend',
    isDefault: true,
  ),
  BattleModeInfo(
    mode: BattleMode.group,
    title: 'Group Battle',
    subtitle: 'Up to 8 players',
  ),
  BattleModeInfo(
    mode: BattleMode.national,
    title: 'National League',
    subtitle: 'Ranked matchmaking',
  ),
  BattleModeInfo(
    mode: BattleMode.school,
    title: 'School vs School',
    subtitle: 'Team tournament',
  ),
];

const sampleBattleQuestions = [
  BattleQuestion(
    text: 'What is the SI unit of electric current?',
    options: ['Ampere', 'Volt', 'Ohm', 'Watt'],
    correctIndex: 0,
    explanation: 'Ampere measures current flow in a circuit.',
  ),
  BattleQuestion(
    text: 'Which law states F = ma?',
    options: [
      'Newton\'s First Law',
      'Newton\'s Second Law',
      'Newton\'s Third Law',
      'Hooke\'s Law',
    ],
    correctIndex: 1,
    explanation: 'Newton\'s Second Law links force, mass, and acceleration.',
  ),
  BattleQuestion(
    text: 'What is the speed of light in vacuum?',
    options: [
      '3 × 10⁶ m/s',
      '3 × 10⁸ m/s',
      '3 × 10¹⁰ m/s',
      '3 × 10⁴ m/s',
    ],
    correctIndex: 1,
    explanation: 'Light travels at approximately 3 × 10⁸ m/s in a vacuum.',
  ),
];

String battleModeLabel(BattleMode mode) {
  switch (mode) {
    case BattleMode.duel:
      return '1v1';
    case BattleMode.group:
      return 'Group';
    case BattleMode.national:
      return 'National';
    case BattleMode.school:
      return 'School';
  }
}

IconData battleModeIcon(BattleMode mode) {
  switch (mode) {
    case BattleMode.duel:
      return Icons.person_outline;
    case BattleMode.group:
      return Icons.groups_outlined;
    case BattleMode.national:
      return Icons.emoji_events_outlined;
    case BattleMode.school:
      return Icons.school_outlined;
  }
}

class OpenBattle {
  OpenBattle({
    required this.id,
    required this.subjectName,
    required this.hostName,
    required this.hostInitials,
    required this.hostGrade,
    required this.joinedCount,
    required this.maxPlayers,
    required this.mode,
    this.isHostedByCurrentUser = false,
    int? minutesAgo,
    List<String>? playerInitials,
  })  : minutesAgo = minutesAgo ?? 0,
        playerInitials = playerInitials ?? const [];

  final String id;
  final String subjectName;
  final String hostName;
  final String hostInitials;
  final String hostGrade;
  final int joinedCount;
  final int maxPlayers;
  final BattleMode mode;
  final bool isHostedByCurrentUser;
  final int minutesAgo;
  final List<String> playerInitials;

  /// Safe accessor for lists rebuilt across hot reload.
  int get elapsedMinutes {
    try {
      final value = minutesAgo;
      return value;
    } catch (_) {
      return 0;
    }
  }

  bool get isFull => joinedCount >= maxPlayers;

  int get spotsLeft => (maxPlayers - joinedCount).clamp(0, maxPlayers);

  double get fillRatio =>
      maxPlayers == 0 ? 0 : joinedCount / maxPlayers;

  String get slotsLabel => '$joinedCount/$maxPlayers joined';

  String get timeAgoLabel {
    final elapsed = elapsedMinutes;
    if (elapsed <= 0) return 'Just now';
    if (elapsed < 60) return '${elapsed}m ago';
    return '${elapsed ~/ 60}h ago';
  }

  bool get isAlmostFull => !isFull && spotsLeft == 1;

  bool get isHot =>
      !isFull && fillRatio >= 0.55 && elapsedMinutes <= 15;

  String? get urgencyLabel {
    if (isFull) return null;
    if (isAlmostFull) return '1 spot left';
    if (isHot) return 'Filling fast';
    if (elapsedMinutes <= 2) return 'Just opened';
    return null;
  }

  List<String> get displayPlayerInitials {
    if (playerInitials.isNotEmpty) return playerInitials;
    return List<String>.generate(
      joinedCount.clamp(1, maxPlayers),
      (i) => i == 0 ? hostInitials : '?',
    );
  }

  OpenBattle copyWith({
    int? joinedCount,
    bool? isHostedByCurrentUser,
    int? minutesAgo,
    List<String>? playerInitials,
  }) {
    return OpenBattle(
      id: id,
      subjectName: subjectName,
      hostName: hostName,
      hostInitials: hostInitials,
      hostGrade: hostGrade,
      joinedCount: joinedCount ?? this.joinedCount,
      maxPlayers: maxPlayers,
      mode: mode,
      isHostedByCurrentUser:
          isHostedByCurrentUser ?? this.isHostedByCurrentUser,
      minutesAgo: minutesAgo ?? this.minutesAgo,
      playerInitials: playerInitials ?? this.playerInitials,
    );
  }
}

final initialOpenBattles = <OpenBattle>[
  OpenBattle(
    id: 'battle-1',
    subjectName: 'Physics',
    hostName: 'Daniel M.',
    hostInitials: 'DM',
    hostGrade: 'Grade 10',
    joinedCount: 3,
    maxPlayers: 8,
    mode: BattleMode.group,
    minutesAgo: 2,
    playerInitials: ['DM', 'HB', 'KR'],
  ),
  OpenBattle(
    id: 'battle-2',
    subjectName: 'Mathematics',
    hostName: 'Hanna B.',
    hostInitials: 'HB',
    hostGrade: 'Grade 10',
    joinedCount: 5,
    maxPlayers: 8,
    mode: BattleMode.group,
    minutesAgo: 5,
    playerInitials: ['HB', 'ST', 'DM', 'MA', 'YK'],
  ),
  OpenBattle(
    id: 'battle-3',
    subjectName: 'Chemistry',
    hostName: 'Meron A.',
    hostInitials: 'MA',
    hostGrade: 'Grade 11',
    joinedCount: 1,
    maxPlayers: 2,
    mode: BattleMode.duel,
    minutesAgo: 1,
    playerInitials: ['MA'],
  ),
  OpenBattle(
    id: 'battle-4',
    subjectName: 'Biology',
    hostName: 'Yonas K.',
    hostInitials: 'YK',
    hostGrade: 'Grade 9',
    joinedCount: 6,
    maxPlayers: 8,
    mode: BattleMode.group,
    minutesAgo: 12,
    playerInitials: ['YK', 'ST', 'HB', 'DM', 'MA', 'KR'],
  ),
];
