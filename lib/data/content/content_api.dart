import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// CMS content models (mirrors dashboard / shared/content).
class ContentGrade {
  const ContentGrade({
    required this.id,
    required this.label,
    this.stream,
  });

  final String id;
  final String label;
  final String? stream;

  factory ContentGrade.fromJson(Map<String, dynamic> json) {
    return ContentGrade(
      id: json['id'] as String,
      label: json['label'] as String,
      stream: json['stream'] as String?,
    );
  }
}

class ContentSubject {
  const ContentSubject({
    required this.id,
    required this.name,
    required this.gradeId,
    required this.locked,
  });

  final String id;
  final String name;
  final String gradeId;
  final bool locked;

  factory ContentSubject.fromJson(Map<String, dynamic> json) {
    return ContentSubject(
      id: json['id'] as String,
      name: json['name'] as String,
      gradeId: json['gradeId'] as String,
      locked: json['locked'] as bool? ?? false,
    );
  }
}

class ContentChapter {
  const ContentChapter({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.subtitle,
    required this.order,
  });

  final String id;
  final String subjectId;
  final String title;
  final String subtitle;
  final int order;

  factory ContentChapter.fromJson(Map<String, dynamic> json) {
    return ContentChapter(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}

class ContentLesson {
  const ContentLesson({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.durationMinutes,
    required this.status,
    this.order = 0,
  });

  final String id;
  final String chapterId;
  final String title;
  final int order;
  final int durationMinutes;
  final String status;

  factory ContentLesson.fromJson(Map<String, dynamic> json) {
    return ContentLesson(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      title: json['title'] as String,
      order: (json['order'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 10,
      status: json['status'] as String? ?? 'draft',
    );
  }

  bool get isPublished => status == 'published';
}

class ContentNote {
  const ContentNote({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.bodyHtml,
    required this.status,
    this.lessonId,
  });

  final String id;
  final String chapterId;
  final String? lessonId;
  final String title;
  final String bodyHtml;
  final String status;

  factory ContentNote.fromJson(Map<String, dynamic> json) {
    return ContentNote(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      lessonId: json['lessonId'] as String?,
      title: json['title'] as String,
      bodyHtml: json['bodyHtml'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
    );
  }

  bool get isPublished => status == 'published';
}

class ContentFlashcardDeck {
  const ContentFlashcardDeck({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.order,
    required this.status,
  });

  final String id;
  final String chapterId;
  final String title;
  final int order;
  final String status;

  factory ContentFlashcardDeck.fromJson(Map<String, dynamic> json) {
    return ContentFlashcardDeck(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      title: json['title'] as String? ?? 'Deck',
      order: (json['order'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'draft',
    );
  }

  bool get isPublished => status == 'published';
}

class ContentFlashcard {
  const ContentFlashcard({
    required this.id,
    required this.chapterId,
    required this.front,
    required this.back,
    required this.order,
    required this.status,
    this.deckId,
  });

  final String id;
  final String chapterId;
  final String? deckId;
  final String front;
  final String back;
  final int order;
  final String status;

  factory ContentFlashcard.fromJson(Map<String, dynamic> json) {
    return ContentFlashcard(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      deckId: json['deckId'] as String?,
      front: json['front'] as String? ?? '',
      back: json['back'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'draft',
    );
  }

  bool get isPublished => status == 'published';
}

class ContentQuestion {
  const ContentQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
    this.gradeId,
    this.subjectId,
    this.chapterId,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String? gradeId;
  final String? subjectId;
  final String? chapterId;

  factory ContentQuestion.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    return ContentQuestion(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      options: options.length >= 4
          ? options.take(4).toList()
          : [...options, ...List.filled(4 - options.length, '')],
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: json['explanation'] as String? ?? '',
      gradeId: json['gradeId'] as String?,
      subjectId: json['subjectId'] as String?,
      chapterId: json['chapterId'] as String?,
    );
  }
}

class ContentQuiz {
  const ContentQuiz({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.questionCount,
    required this.status,
    this.noteId,
    this.questions = const [],
  });

  final String id;
  final String chapterId;
  final String? noteId;
  final String title;
  final int questionCount;
  final String status;
  final List<ContentQuestion> questions;

  factory ContentQuiz.fromJson(Map<String, dynamic> json) {
    return ContentQuiz(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      noteId: json['noteId'] as String?,
      title: json['title'] as String,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'draft',
      questions: (json['questions'] as List<dynamic>? ?? const [])
          .map((e) => ContentQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isPublished => status == 'published';
}

class ContentChapterExam {
  const ContentChapterExam({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.questionCount,
    required this.durationMinutes,
    required this.status,
    this.questions = const [],
  });

  final String id;
  final String chapterId;
  final String title;
  final int questionCount;
  final int durationMinutes;
  final String status;
  final List<ContentQuestion> questions;

  factory ContentChapterExam.fromJson(Map<String, dynamic> json) {
    return ContentChapterExam(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      title: json['title'] as String,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'draft',
      questions: (json['questions'] as List<dynamic>? ?? const [])
          .map((e) => ContentQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isPublished => status == 'published';
}

class ContentSubjectExam {
  const ContentSubjectExam({
    required this.id,
    required this.subjectId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.questionCount,
    required this.durationMinutes,
    required this.status,
    this.year,
    this.gradeId,
    this.questions = const [],
  });

  final String id;
  final String subjectId;
  final String type;
  final String title;
  final String subtitle;
  final int questionCount;
  final int durationMinutes;
  final String status;
  final int? year;
  final String? gradeId;
  final List<ContentQuestion> questions;

  factory ContentSubjectExam.fromJson(Map<String, dynamic> json) {
    return ContentSubjectExam(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'draft',
      year: (json['year'] as num?)?.toInt(),
      gradeId: json['gradeId'] as String?,
      questions: (json['questions'] as List<dynamic>? ?? const [])
          .map((e) => ContentQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isPublished => status == 'published';
}

class ContentCatalog {
  const ContentCatalog({
    required this.grades,
    required this.subjects,
    required this.chapters,
    required this.lessons,
    required this.notes,
    required this.flashcardDecks,
    required this.flashcards,
    required this.quizzes,
    required this.chapterExams,
    required this.exams,
  });

  final List<ContentGrade> grades;
  final List<ContentSubject> subjects;
  final List<ContentChapter> chapters;
  final List<ContentLesson> lessons;
  final List<ContentNote> notes;
  final List<ContentFlashcardDeck> flashcardDecks;
  final List<ContentFlashcard> flashcards;
  final List<ContentQuiz> quizzes;
  final List<ContentChapterExam> chapterExams;
  final List<ContentSubjectExam> exams;

  factory ContentCatalog.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(
      String key,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return ContentCatalog(
      grades: parseList('grades', ContentGrade.fromJson),
      subjects: parseList('subjects', ContentSubject.fromJson),
      chapters: parseList('chapters', ContentChapter.fromJson),
      lessons: parseList('lessons', ContentLesson.fromJson),
      notes: parseList('notes', ContentNote.fromJson),
      flashcardDecks: parseList('flashcardDecks', ContentFlashcardDeck.fromJson),
      flashcards: parseList('flashcards', ContentFlashcard.fromJson),
      quizzes: parseList('quizzes', ContentQuiz.fromJson),
      chapterExams: parseList('chapterExams', ContentChapterExam.fromJson),
      exams: parseList('exams', ContentSubjectExam.fromJson),
    );
  }

  ContentGrade? gradeByLabel(String label) {
    for (final g in grades) {
      if (g.label == label) return g;
    }
    // Soft match: "Grade 11" → first Grade 11 · …
    final base = label.split('·').first.trim();
    for (final g in grades) {
      if (g.label == base || g.label.startsWith('$base ·')) return g;
    }
    return null;
  }

  ContentSubject? subjectFor({
    required String subjectName,
    required String gradeLabel,
  }) {
    final grade = gradeByLabel(gradeLabel);
    if (grade == null) return null;
    for (final s in subjects) {
      if (s.name == subjectName && s.gradeId == grade.id) return s;
    }
    return null;
  }
}

/// Resolves the dashboard content API base URL.
///
/// On a physical phone, `127.0.0.1` is the phone itself — use the Mac LAN IP.
/// Override anytime with `--dart-define=CONTENT_API_BASE=http://IP:5173`.
String contentApiBaseUrl() {
  const fromEnv = String.fromEnvironment(
    'CONTENT_API_BASE',
    defaultValue: '',
  );
  if (fromEnv.isNotEmpty) return fromEnv;

  // Mac LAN IP for device testing (update if your Wi‑Fi IP changes).
  const lanBase = String.fromEnvironment(
    'CONTENT_API_LAN',
    defaultValue: 'http://192.168.8.102:5173',
  );

  if (kIsWeb) return 'http://127.0.0.1:5173';

  // iOS Simulator can use loopback; physical iPhone/Android need LAN.
  final useLan = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  if (useLan) return lanBase;

  return 'http://127.0.0.1:5173';
}

class ContentApi {
  ContentApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Fetches the live CMS catalog. Throws / returns null on failure.
  Future<({ContentCatalog catalog, Map<String, dynamic> json})?>
      fetchCatalogFromNetwork() async {
    final uri = Uri.parse('${contentApiBaseUrl()}/api/content');
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 4));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final catalogJson =
        (decoded['catalog'] as Map<String, dynamic>?) ?? decoded;
    return (
      catalog: ContentCatalog.fromJson(catalogJson),
      json: catalogJson,
    );
  }

  /// Legacy helper — local seed only (prefer [ContentStore.load]).
  Future<ContentCatalog> fetchCatalog() async {
    return loadBundledCatalog();
  }

  static Future<ContentCatalog> loadBundledCatalog() async {
    final raw = await rootBundle.loadString('assets/content/data.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return ContentCatalog.fromJson(decoded);
  }
}
