import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_colors.dart';

enum ContentType {
  notes,
  flashcard,
  exam,
  ai,
}

extension ContentTypeStyle on ContentType {
  Color get backgroundColor {
    switch (this) {
      case ContentType.notes:
        return AppColors.accentSoft;
      case ContentType.flashcard:
        return AppColors.successSoft;
      case ContentType.exam:
        return AppColors.warningSoft;
      case ContentType.ai:
        return AppColors.infoSoft;
    }
  }

  Color get iconColor {
    switch (this) {
      case ContentType.notes:
        return AppColors.accentText;
      case ContentType.flashcard:
        return AppColors.success;
      case ContentType.exam:
        return AppColors.warning;
      case ContentType.ai:
        return AppColors.info;
    }
  }

  IconData get icon {
    switch (this) {
      case ContentType.notes:
        return LucideIcons.bookOpen;
      case ContentType.flashcard:
        return LucideIcons.layers;
      case ContentType.exam:
        return LucideIcons.fileText;
      case ContentType.ai:
        return LucideIcons.sparkles;
    }
  }

  String get label {
    switch (this) {
      case ContentType.notes:
        return 'Notes';
      case ContentType.flashcard:
        return 'Cards';
      case ContentType.exam:
        return 'Exam';
      case ContentType.ai:
        return 'AI';
    }
  }
}
