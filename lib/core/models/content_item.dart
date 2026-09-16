import 'content_type.dart';

class ContentItem {
  const ContentItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.subject,
    this.progress,
    this.isBookmarked = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final ContentType type;
  final String subject;
  final double? progress;
  final bool isBookmarked;
}
