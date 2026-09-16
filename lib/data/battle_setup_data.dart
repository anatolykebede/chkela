import 'dart:math';

import 'home_mock_data.dart';

enum BattleFormat { oneVsOne, teamVsTeam }

enum BattleVisibility { public, private }

enum BattleGameMode { classicQuiz, rapidFire, survival }

enum BattleDifficulty { easy, medium, hard }

enum ParticipantStatus { waiting, joined, ready }

class BattleFriend {
  const BattleFriend({
    required this.id,
    required this.name,
    required this.initials,
    required this.grade,
    required this.points,
    this.isOnline = true,
  });

  final String id;
  final String name;
  final String initials;
  final String grade;
  final int points;
  final bool isOnline;
}

const battleFriends = [
  BattleFriend(
    id: 'hanna-b',
    name: 'Hanna B.',
    initials: 'HB',
    grade: 'Grade 10',
    points: 4820,
  ),
  BattleFriend(
    id: 'daniel-m',
    name: 'Daniel M.',
    initials: 'DM',
    grade: 'Grade 10',
    points: 4510,
  ),
  BattleFriend(
    id: 'meron-a',
    name: 'Meron A.',
    initials: 'MA',
    grade: 'Grade 10',
    points: 4380,
  ),
  BattleFriend(
    id: 'yonas-k',
    name: 'Yonas K.',
    initials: 'YK',
    grade: 'Grade 9',
    points: 3920,
    isOnline: false,
  ),
  BattleFriend(
    id: 'sara-t',
    name: 'Sara T.',
    initials: 'ST2',
    grade: 'Grade 11',
    points: 4100,
  ),
];

const battleGameModes = [
  (BattleGameMode.classicQuiz, 'Classic Quiz', 'Standard multiple choice'),
  (BattleGameMode.rapidFire, 'Rapid Fire', 'Shorter timer, bonus streaks'),
  (BattleGameMode.survival, 'Survival', 'Wrong answer eliminates you'),
];

const battleTimeLimits = [10, 15, 20, 30];

const battleRoundCounts = [5, 10, 15, 20];

const battleDifficulties = [
  (BattleDifficulty.easy, 'Easy'),
  (BattleDifficulty.medium, 'Medium'),
  (BattleDifficulty.hard, 'Hard'),
];

String battleFormatLabel(BattleFormat format) {
  switch (format) {
    case BattleFormat.oneVsOne:
      return '1v1';
    case BattleFormat.teamVsTeam:
      return 'Team vs Team';
  }
}

String battleVisibilityLabel(BattleVisibility visibility) {
  switch (visibility) {
    case BattleVisibility.public:
      return 'Public';
    case BattleVisibility.private:
      return 'Private';
  }
}

String battleGameModeLabel(BattleGameMode mode) {
  switch (mode) {
    case BattleGameMode.classicQuiz:
      return 'Classic Quiz';
    case BattleGameMode.rapidFire:
      return 'Rapid Fire';
    case BattleGameMode.survival:
      return 'Survival';
  }
}

String battleDifficultyLabel(BattleDifficulty difficulty) {
  switch (difficulty) {
    case BattleDifficulty.easy:
      return 'Easy';
    case BattleDifficulty.medium:
      return 'Medium';
    case BattleDifficulty.hard:
      return 'Hard';
  }
}

int maxPlayersForFormat(BattleFormat format) =>
    format == BattleFormat.oneVsOne ? 2 : 8;

class BattleSetup {
  BattleSetup({
    required this.id,
    required this.inviteCode,
    required this.format,
    required this.visibility,
    required this.subjectName,
    required this.gameMode,
    required this.timeLimitSeconds,
    required this.roundCount,
    required this.difficulty,
    required this.invitedFriendIds,
    required this.randomMatchmaking,
    required this.rewardPoints,
    required this.pointsAmount,
    required this.rewardBadges,
    required this.rewardPrizePool,
    required this.prizePoolLabel,
    required this.hostName,
    required this.hostInitials,
    required this.hostGrade,
  });

  final String id;
  final String inviteCode;
  final BattleFormat format;
  final BattleVisibility visibility;
  final String subjectName;
  final BattleGameMode gameMode;
  final int timeLimitSeconds;
  final int roundCount;
  final BattleDifficulty difficulty;
  final Set<String> invitedFriendIds;
  final bool randomMatchmaking;
  final bool rewardPoints;
  final int pointsAmount;
  final bool rewardBadges;
  final bool rewardPrizePool;
  final String prizePoolLabel;
  final String hostName;
  final String hostInitials;
  final String hostGrade;

  int get maxPlayers => maxPlayersForFormat(format);

  String get inviteLink => 'https://chkela.app/battle/$inviteCode';

  bool get hasRewards => rewardPoints || rewardBadges || rewardPrizePool;
}

class BattleParticipant {
  BattleParticipant({
    required this.id,
    required this.name,
    required this.initials,
    required this.grade,
    required this.status,
    this.isHost = false,
    this.isCurrentUser = false,
  });

  final String id;
  final String name;
  final String initials;
  final String grade;
  final ParticipantStatus status;
  final bool isHost;
  final bool isCurrentUser;

  BattleParticipant copyWith({ParticipantStatus? status}) {
    return BattleParticipant(
      id: id,
      name: name,
      initials: initials,
      grade: grade,
      status: status ?? this.status,
      isHost: isHost,
      isCurrentUser: isCurrentUser,
    );
  }
}

List<BattleParticipant> initialParticipantsForSetup(BattleSetup setup) {
  final participants = <BattleParticipant>[
    BattleParticipant(
      id: 'host',
      name: setup.hostName,
      initials: setup.hostInitials,
      grade: setup.hostGrade,
      status: ParticipantStatus.ready,
      isHost: true,
      isCurrentUser: true,
    ),
  ];

  for (final friendId in setup.invitedFriendIds) {
    final friend = battleFriends.firstWhere((f) => f.id == friendId);
    participants.add(
      BattleParticipant(
        id: friend.id,
        name: friend.name,
        initials: friend.initials,
        grade: friend.grade,
        status: ParticipantStatus.waiting,
      ),
    );
  }

  if (setup.randomMatchmaking && setup.visibility == BattleVisibility.public) {
    participants.add(
      BattleParticipant(
        id: 'matchmaking',
        name: 'Finding opponent…',
        initials: '?',
        grade: 'Matchmaking',
        status: ParticipantStatus.waiting,
      ),
    );
  }

  return participants;
}

String generateInviteCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random();
  final code = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  return 'CHK-$code';
}

BattleSetup defaultBattleSetup({String? subjectName}) {
  return BattleSetup(
    id: 'battle-${DateTime.now().millisecondsSinceEpoch}',
    inviteCode: generateInviteCode(),
    format: BattleFormat.oneVsOne,
    visibility: BattleVisibility.public,
    subjectName: subjectName ?? 'Physics',
    gameMode: BattleGameMode.classicQuiz,
    timeLimitSeconds: 15,
    roundCount: 10,
    difficulty: BattleDifficulty.medium,
    invitedFriendIds: {},
    randomMatchmaking: true,
    rewardPoints: true,
    pointsAmount: 50,
    rewardBadges: false,
    rewardPrizePool: false,
    prizePoolLabel: '',
    hostName: studentName,
    hostInitials: studentInitials,
    hostGrade: enrolledGrade,
  );
}
