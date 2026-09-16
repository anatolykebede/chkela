// Pts-based rank tiers and milestone thresholds (composite leaderboard points).

enum PointsRankTier {
  rookie,
  bronze,
  silver,
  gold,
  platinum,
  diamond,
}

class PointsRankTierInfo {
  const PointsRankTierInfo({
    required this.tier,
    required this.minPoints,
    required this.label,
  });

  final PointsRankTier tier;
  final int minPoints;
  final String label;
}

class PointsMilestone {
  const PointsMilestone({
    required this.minPoints,
    required this.label,
  });

  final int minPoints;
  final String label;
}

const pointsRankCatalog = <PointsRankTierInfo>[
  PointsRankTierInfo(
    tier: PointsRankTier.rookie,
    minPoints: 0,
    label: 'Rookie',
  ),
  PointsRankTierInfo(
    tier: PointsRankTier.bronze,
    minPoints: 250,
    label: 'Bronze',
  ),
  PointsRankTierInfo(
    tier: PointsRankTier.silver,
    minPoints: 750,
    label: 'Silver',
  ),
  PointsRankTierInfo(
    tier: PointsRankTier.gold,
    minPoints: 2000,
    label: 'Gold',
  ),
  PointsRankTierInfo(
    tier: PointsRankTier.platinum,
    minPoints: 5000,
    label: 'Platinum',
  ),
  PointsRankTierInfo(
    tier: PointsRankTier.diamond,
    minPoints: 10000,
    label: 'Diamond',
  ),
];

const pointsMilestoneCatalog = <PointsMilestone>[
  PointsMilestone(minPoints: 100, label: '100 pts'),
  PointsMilestone(minPoints: 250, label: '250 pts'),
  PointsMilestone(minPoints: 500, label: '500 pts'),
  PointsMilestone(minPoints: 1000, label: '1k pts'),
  PointsMilestone(minPoints: 2500, label: '2.5k pts'),
  PointsMilestone(minPoints: 5000, label: '5k pts'),
  PointsMilestone(minPoints: 10000, label: '10k pts'),
];

PointsRankTierInfo pointsRankFor(int points) {
  final safe = points < 0 ? 0 : points;
  var current = pointsRankCatalog.first;
  for (final info in pointsRankCatalog) {
    if (safe >= info.minPoints) {
      current = info;
    } else {
      break;
    }
  }
  return current;
}

PointsRankTierInfo? pointsNextRank(int points) {
  final current = pointsRankFor(points);
  final index = pointsRankCatalog.indexWhere((e) => e.tier == current.tier);
  if (index < 0 || index >= pointsRankCatalog.length - 1) return null;
  return pointsRankCatalog[index + 1];
}

String pointsNextRankHint(int points) {
  final next = pointsNextRank(points);
  if (next == null) return 'Max rank unlocked';
  return 'Next: ${next.label} at ${_formatThreshold(next.minPoints)} pts';
}

List<PointsMilestone> unlockedPointsMilestones(int points) {
  final safe = points < 0 ? 0 : points;
  return [
    for (final m in pointsMilestoneCatalog)
      if (safe >= m.minPoints) m,
  ];
}

String _formatThreshold(int value) {
  if (value >= 1000) {
    final whole = value ~/ 1000;
    final rem = value % 1000;
    if (rem == 0) return '${whole}k';
    if (rem % 100 == 0) return '$whole.${rem ~/ 100}k';
    return '$value';
  }
  return '$value';
}
