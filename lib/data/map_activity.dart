import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

enum MapActivityKind {
  note,
  cards,
  exam,
  path,
  streak,
  social,
  challenge,
}

class MapActivityItem {
  const MapActivityItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    this.ctaLabel,
    this.ctaRoute,
  });

  final String id;
  final MapActivityKind kind;
  final String title;
  final String subtitle;
  final String timeLabel;
  final String? ctaLabel;
  final String? ctaRoute;

  IconData get icon => switch (kind) {
        MapActivityKind.note => Icons.menu_book_outlined,
        MapActivityKind.cards => Icons.style_outlined,
        MapActivityKind.exam => Icons.fact_check_outlined,
        MapActivityKind.path => Icons.route_rounded,
        MapActivityKind.streak => Icons.local_fire_department_outlined,
        MapActivityKind.social => Icons.favorite_outline,
        MapActivityKind.challenge => Icons.sports_esports_outlined,
      };

  Color get color => switch (kind) {
        MapActivityKind.note => AppColors.accentText,
        MapActivityKind.cards => AppColors.info,
        MapActivityKind.exam => AppColors.amber,
        MapActivityKind.path => AppColors.teal,
        MapActivityKind.streak => AppColors.gold,
        MapActivityKind.social => AppColors.fabPink,
        MapActivityKind.challenge => AppColors.accent,
      };
}
