import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only study progress (notes, cards, chapter exams) on device.
class StudyProgressStore extends ChangeNotifier {
  StudyProgressStore._();
  static final instance = StudyProgressStore._();

  static const _prefsKey = 'chkela_study_progress_v1';

  final Set<String> _notes = {};
  final Set<String> _decks = {};
  final Set<String> _chapterExams = {};
  var _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _notes
          ..clear()
          ..addAll(_stringSet(decoded['notes']));
        _decks
          ..clear()
          ..addAll(_stringSet(decoded['decks']));
        _chapterExams
          ..clear()
          ..addAll(_stringSet(decoded['chapterExams']));
      } catch (_) {
        // Keep empty sets on corrupt data.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'notes': _notes.toList(),
        'decks': _decks.toList(),
        'chapterExams': _chapterExams.toList(),
      }),
    );
    notifyListeners();
  }

  bool isNoteDone(String noteId) => _notes.contains(noteId);

  bool isDeckDone(String deckId) => _decks.contains(deckId);

  bool isChapterExamDone(String chapterId) =>
      _chapterExams.contains(chapterId);

  int get notesCompleted => _notes.length;

  int get decksCompleted => _decks.length;

  int get chapterExamsCompleted => _chapterExams.length;

  List<String> get completedNoteIds => _notes.toList(growable: false);

  List<String> get completedDeckIds => _decks.toList(growable: false);

  List<String> get completedChapterExamIds =>
      _chapterExams.toList(growable: false);

  bool isDeckDoneForChapter(String chapterId, String deckId) {
    return isDeckDone(deckId) || isDeckDone(chapterDeckKey(chapterId));
  }

  static String chapterDeckKey(String chapterId) => '${chapterId}__cards';

  Future<void> markNoteDone(String noteId) async {
    if (noteId.isEmpty) return;
    await load();
    if (_notes.contains(noteId)) return;
    _notes.add(noteId);
    await _persist();
  }

  Future<void> markDeckDone(String deckId) async {
    if (deckId.isEmpty) return;
    await load();
    if (_decks.contains(deckId)) return;
    _decks.add(deckId);
    await _persist();
  }

  /// Marks chapter flashcards when no specific deck id was used.
  Future<void> markChapterFlashcardsDone(String chapterId) async {
    await markDeckDone(chapterDeckKey(chapterId));
  }

  Future<void> markChapterExamDone(String chapterId) async {
    if (chapterId.isEmpty) return;
    await load();
    if (_chapterExams.contains(chapterId)) return;
    _chapterExams.add(chapterId);
    await _persist();
  }
}

Set<String> _stringSet(dynamic raw) {
  if (raw is! List) return {};
  return {
    for (final e in raw)
      if ('$e'.trim().isNotEmpty) '$e'.trim(),
  };
}
