import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the student is currently studying (drives AI tutor context).
class AiStudyContext {
  const AiStudyContext({
    this.grade = '',
    this.subject = '',
    this.chapter = '',
    this.note = '',
    this.noteSnippet = '',
  });

  final String grade;
  final String subject;
  final String chapter;
  final String note;
  final String noteSnippet;

  bool get hasFocus =>
      subject.trim().isNotEmpty ||
      chapter.trim().isNotEmpty ||
      note.trim().isNotEmpty;

  String get label {
    final parts = <String>[
      if (subject.trim().isNotEmpty) subject.trim(),
      if (chapter.trim().isNotEmpty) chapter.trim(),
    ];
    if (parts.isEmpty) return 'General study';
    return parts.join(' · ');
  }

  String get inputHint {
    if (chapter.trim().isNotEmpty) {
      return 'Ask anything about $chapter…';
    }
    if (subject.trim().isNotEmpty) {
      return 'Ask anything about $subject…';
    }
    return 'Ask anything about what you are studying…';
  }

  Map<String, dynamic> toJson() => {
        'grade': grade,
        'subject': subject,
        'chapter': chapter,
        'note': note,
        'noteSnippet': noteSnippet,
      };

  AiStudyContext copyWith({
    String? grade,
    String? subject,
    String? chapter,
    String? note,
    String? noteSnippet,
  }) {
    return AiStudyContext(
      grade: grade ?? this.grade,
      subject: subject ?? this.subject,
      chapter: chapter ?? this.chapter,
      note: note ?? this.note,
      noteSnippet: noteSnippet ?? this.noteSnippet,
    );
  }
}

final aiStudyContextProvider =
    StateProvider<AiStudyContext>((ref) => const AiStudyContext());
