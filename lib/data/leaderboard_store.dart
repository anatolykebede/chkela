import 'dart:async';

import 'package:flutter/foundation.dart';

import 'leaderboard_api.dart';
import 'leaderboard_data.dart';
import 'path_progress_store.dart';
import 'study_progress_store.dart';

/// Fetches shared grade rankings and keeps the signed-in student's score synced.
class LeaderboardStore extends ChangeNotifier {
  LeaderboardStore._() {
    PathProgressStore.instance.addListener(_onProgressChanged);
    StudyProgressStore.instance.addListener(_onProgressChanged);
  }

  static final instance = LeaderboardStore._();

  final LeaderboardApi _api = LeaderboardApi();

  String? _phone;
  String? _fullName;
  String? _grade;
  List<RemoteLeaderboardEntry> _remote = const [];
  List<LeaderboardEntry> _entries = const [];
  bool _loading = false;
  bool _boundProgress = true;
  Timer? _syncDebounce;
  int _lastSyncedPoints = -1;

  List<LeaderboardEntry> get entries => _entries;
  bool get loading => _loading;

  void configure({
    required String? phoneE164,
    required String? fullName,
    required String? grade,
  }) {
    final nextPhone = phoneE164?.trim();
    final nextName = fullName?.trim();
    final nextGrade = grade?.trim();
    final changed = nextPhone != _phone ||
        nextName != _fullName ||
        nextGrade != _grade;
    _phone = nextPhone;
    _fullName = nextName;
    _grade = nextGrade;
    if (changed) {
      _rebuildLocalFallback();
      unawaited(refresh());
    } else {
      _rebuildLocalFallback();
    }
  }

  void _onProgressChanged() {
    _rebuildLocalFallback();
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(refresh(forceUpsert: true));
    });
  }

  void _rebuildLocalFallback() {
    _entries = mergeLeaderboard(
      phoneE164: _phone,
      fullName: _fullName,
      grade: _grade,
      remote: _remote,
    );
    notifyListeners();
  }

  Future<void> refresh({bool forceUpsert = false}) async {
    final phone = _phone;
    final grade = _grade;
    if (phone == null || phone.isEmpty || grade == null || grade.isEmpty) {
      _rebuildLocalFallback();
      return;
    }

    final points = computeLeaderboardPoints(
      PathProgressStore.instance,
      StudyProgressStore.instance,
    );
    final displayName = (_fullName?.trim().isNotEmpty ?? false)
        ? _fullName!.trim()
        : 'Student';

    _loading = true;
    notifyListeners();

    try {
      if (forceUpsert || points != _lastSyncedPoints) {
        await _api.upsertScore(
          phoneE164: phone,
          displayName: displayName,
          grade: grade,
          points: points,
        );
        _lastSyncedPoints = points;
      }
      _remote = await _api.listByGrade(grade);
    } catch (e) {
      debugPrint('Leaderboard refresh failed: $e');
    } finally {
      _loading = false;
      _rebuildLocalFallback();
    }
  }

  @override
  void dispose() {
    if (_boundProgress) {
      PathProgressStore.instance.removeListener(_onProgressChanged);
      StudyProgressStore.instance.removeListener(_onProgressChanged);
      _boundProgress = false;
    }
    _syncDebounce?.cancel();
    super.dispose();
  }
}
