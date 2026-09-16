import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/auth_session_store.dart';
import 'friends_api.dart';
import 'home_mock_data.dart';
import 'leaderboard_data.dart';
import 'map_activity.dart';
import 'map_student_social.dart';
import 'map_students.dart';
import 'path_progress_store.dart';
import 'study_progress_store.dart';

/// Cities / areas a student can pin themselves on the map.
class MapProfileCity {
  const MapProfileCity({
    required this.id,
    required this.label,
    required this.location,
  });

  final String id;
  final String label;
  final LatLng location;
}

const mapProfileCities = [
  MapProfileCity(
    id: 'addis-bole',
    label: 'Addis Ababa · Bole',
    location: LatLng(8.9881, 38.7890),
  ),
  MapProfileCity(
    id: 'addis-piassa',
    label: 'Addis Ababa · Piassa',
    location: LatLng(9.0320, 38.7469),
  ),
  MapProfileCity(
    id: 'addis-cmc',
    label: 'Addis Ababa · CMC',
    location: LatLng(9.0192, 38.8035),
  ),
  MapProfileCity(
    id: 'addis-ayat',
    label: 'Addis Ababa · Ayat',
    location: LatLng(9.0455, 38.8702),
  ),
  MapProfileCity(
    id: 'bahir-dar',
    label: 'Bahir Dar',
    location: LatLng(11.5936, 37.3908),
  ),
  MapProfileCity(
    id: 'hawassa',
    label: 'Hawassa',
    location: LatLng(7.0621, 38.4764),
  ),
  MapProfileCity(
    id: 'dire-dawa',
    label: 'Dire Dawa',
    location: LatLng(9.5931, 41.8661),
  ),
  MapProfileCity(
    id: 'jimma',
    label: 'Jimma',
    location: LatLng(7.6667, 36.8333),
  ),
  MapProfileCity(
    id: 'mekelle',
    label: 'Mekelle',
    location: LatLng(13.4967, 39.4753),
  ),
  MapProfileCity(
    id: 'gondar',
    label: 'Gondar',
    location: LatLng(12.6030, 37.4521),
  ),
];

const mapFocusSubjectOptions = [
  'Mathematics',
  'Physics',
  'Chemistry',
  'Biology',
  'English',
  'History',
  'Geography',
  'Civics',
  'ICT',
  'Economics',
];

/// Live map profile layer: student-authored identity + study/Path stats.
class MapProfileStore extends ChangeNotifier {
  MapProfileStore._();
  static final instance = MapProfileStore._();

  static const _prefsKey = 'chkela_map_profile_v2';
  static const currentUserId = 'selam-tadesse';

  final Set<String> _friendIds = {};
  /// Display info for friends who are not in the local map catalog (phone peers).
  final Map<String, MapStudent> _friendDirectory = {};
  final Map<String, String> _outgoingByPeer = {};
  final Map<String, String> _incomingByPeer = {};
  String? _sessionPhone;
  String? _moodEmoji;
  String? _moodLabel;
  String? _displayName;
  String? _school;
  String? _bio;
  String? _tagline;
  String? _cityId;
  String? _cachedGrade;
  List<String> _subjects = [];
  Set<String> _authInterests = {};
  var _loaded = false;

  bool get isLoaded => _loaded;

  Set<String> get friendIds => Set.unmodifiable(_friendIds);
  int get incomingRequestCount => _incomingByPeer.length;

  String? get displayName => _displayName;
  String? get school => _school;
  String? get bio => _bio;
  String? get tagline => _tagline;
  String? get cityId => _cityId;
  String? get grade => _cachedGrade;
  List<String> get subjects => List.unmodifiable(_subjects);

  bool get isProfileComplete {
    return (_displayName?.trim().isNotEmpty ?? false) &&
        (_school?.trim().isNotEmpty ?? false) &&
        (_bio?.trim().isNotEmpty ?? false) &&
        (_cachedGrade?.trim().isNotEmpty ?? false) &&
        _subjects.isNotEmpty &&
        (_cityId?.isNotEmpty ?? false) &&
        (_moodEmoji?.isNotEmpty ?? false);
  }

  MapProfileCity? get selectedCity {
    final id = _cityId;
    if (id == null) return null;
    for (final city in mapProfileCities) {
      if (city.id == id) return city;
    }
    return null;
  }

  Future<void> load() async {
    await StudyProgressStore.instance.load();
    await PathProgressStore.instance.load(pullRemote: false);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey) ?? prefs.getString('chkela_map_profile_v1');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _friendIds
          ..clear()
          ..addAll(_stringSet(decoded['friendIds']));
        _moodEmoji = decoded['moodEmoji'] as String?;
        _moodLabel = decoded['moodLabel'] as String?;
        _displayName = decoded['displayName'] as String?;
        _school = decoded['school'] as String?;
        _bio = decoded['bio'] as String?;
        _tagline = decoded['tagline'] as String?;
        _cityId = decoded['cityId'] as String?;
        final grade = decoded['grade'] as String?;
        if (grade != null && grade.trim().isNotEmpty) {
          _cachedGrade = grade;
        }
        _subjects = _stringList(decoded['subjects']);
      } catch (_) {}
    }

    final phone = await AuthSessionStore.loadSessionPhone();
    _sessionPhone = phone;
    if (phone != null) {
      final profile = await AuthSessionStore.profileFor(phone);
      _cachedGrade ??= profile?.grade;
      _authInterests = {...?profile?.interests};
      if (_subjects.isEmpty) {
        _subjects = _subjectsFromInterests(_authInterests, const []);
      }
      await refreshFriends(pullRemote: true);
      if (isProfileComplete) {
        await _pushProfileRemote();
      }
    }

    StudyProgressStore.instance.addListener(_onProgressChanged);
    _loaded = true;
    notifyListeners();
  }

  void _onProgressChanged() => notifyListeners();

  Future<void> syncFromAuth({
    String? grade,
    Set<String>? interests,
  }) async {
    var changed = false;
    if (grade != null && grade != _cachedGrade && _cachedGrade == null) {
      _cachedGrade = grade;
      changed = true;
    }
    if (interests != null) {
      _authInterests = {...interests};
      if (_subjects.isEmpty) {
        _subjects = _subjectsFromInterests(_authInterests, const []);
        changed = true;
      }
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'friendIds': _friendIds.toList(),
        'moodEmoji': _moodEmoji,
        'moodLabel': _moodLabel,
        'displayName': _displayName,
        'school': _school,
        'bio': _bio,
        'tagline': _tagline,
        'cityId': _cityId,
        'grade': _cachedGrade,
        'subjects': _subjects,
      }),
    );
  }

  bool isFriend(String studentId) =>
      relationWith(studentId) == FriendRelationStatus.friends;

  FriendRelationStatus relationWith(String studentId) {
    final id = studentId.trim();
    if (id.isEmpty || id == currentUserId) return FriendRelationStatus.none;
    if (_friendIds.contains(id)) return FriendRelationStatus.friends;
    if (_outgoingByPeer.containsKey(id)) return FriendRelationStatus.outgoing;
    if (_incomingByPeer.containsKey(id)) return FriendRelationStatus.incoming;
    return FriendRelationStatus.none;
  }

  String? incomingFriendshipId(String studentId) =>
      _incomingByPeer[studentId.trim()];

  Future<void> refreshFriends({bool pullRemote = true}) async {
    final phone = _sessionPhone ?? await AuthSessionStore.loadSessionPhone();
    _sessionPhone = phone;
    if (phone == null || !pullRemote) {
      notifyListeners();
      return;
    }
    final snap = await FriendsApi.instance.fetch(phone);
    // Keep last good graph when the API is down / returns junk.
    if (snap == null) {
      notifyListeners();
      return;
    }
    _applyFriendsSnapshot(snap);
    await _persist();
    notifyListeners();
  }

  void _applyFriendsSnapshot(FriendsSnapshot snap) {
    _friendIds.clear();
    _friendDirectory.clear();
    _outgoingByPeer.clear();
    _incomingByPeer.clear();

    void indexPeer(FriendEdge edge, Map<String, String> into) {
      final peer = edge.peer;
      if (peer.id.isNotEmpty) into[peer.id] = edge.friendshipId;
      if (peer.targetId.isNotEmpty) into[peer.targetId] = edge.friendshipId;
    }

    void rememberFriend(FriendPeerSummary peer) {
      final routeId =
          peer.targetId.isNotEmpty ? peer.targetId : peer.id;
      if (routeId.isEmpty) return;
      if (routeId == currentUserId || routeId == 'me') return;
      if (_sessionPhone != null && routeId == _sessionPhone) return;

      if (peer.id.isNotEmpty) _friendIds.add(peer.id);
      if (peer.targetId.isNotEmpty) _friendIds.add(peer.targetId);

      final catalog = mapStudentById(routeId) ?? studentById(routeId);
      if (catalog != null && !catalog.isCurrentUser) {
        _friendDirectory[routeId] = catalog;
        return;
      }

      _friendDirectory[routeId] = MapStudent(
        id: routeId,
        name: peer.name.isNotEmpty ? peer.name : routeId,
        initials: peer.initials.isNotEmpty ? peer.initials : '?',
        grade: peer.grade,
        points: 0,
        location: mapDefaultCenter,
        subjects: peer.subjects,
        streak: 0,
        avgScore: 0,
        bio: peer.bio.isEmpty ? null : peer.bio,
        school: peer.school.isEmpty ? 'Chkela student' : peer.school,
      );
    }

    for (final edge in snap.friends) {
      rememberFriend(edge.peer);
    }
    for (final edge in snap.outgoing) {
      indexPeer(edge, _outgoingByPeer);
    }
    for (final edge in snap.incoming) {
      indexPeer(edge, _incomingByPeer);
    }
  }

  Future<void> toggleFriend(String studentId) async {
    final status = relationWith(studentId);
    switch (status) {
      case FriendRelationStatus.friends:
      case FriendRelationStatus.outgoing:
        await removeFriend(studentId);
        return;
      case FriendRelationStatus.incoming:
        await acceptFriend(studentId);
        return;
      case FriendRelationStatus.none:
        await sendFriendRequest(studentId);
    }
  }

  Future<void> sendFriendRequest(String studentId) async {
    if (studentId == currentUserId) return;
    final phone = _sessionPhone ?? await AuthSessionStore.loadSessionPhone();
    final isMapDemo = mapStudentById(studentId) != null &&
        !(mapStudentById(studentId)?.isCurrentUser ?? true);
    if (phone == null) {
      // Offline: only demo map peers can be friended locally.
      if (!isMapDemo) return;
      _friendIds.add(studentId);
      await _persist();
      notifyListeners();
      return;
    }
    _sessionPhone = phone;
    final state = await FriendsApi.instance.request(
      phone: phone,
      targetId: studentId,
    );
    if (state == null) {
      // Soft offline: map demo peers only (API accepts those without friendship).
      if (!isMapDemo) return;
      _friendIds.add(studentId);
      await _persist();
      notifyListeners();
      return;
    }
    await refreshFriends(pullRemote: true);
  }

  /// Matches chat API rules: demo map peers always; real users only if friends.
  bool canMessage(String studentId) {
    final id = studentId.trim();
    if (id.isEmpty || id == currentUserId || id == 'me') return false;
    if (_sessionPhone != null && id == _sessionPhone) return false;
    final catalog = mapStudentById(id);
    if (catalog != null && !catalog.isCurrentUser) return true;
    return isFriend(id);
  }

  Future<void> acceptFriend(String studentId) async {
    final phone = _sessionPhone ?? await AuthSessionStore.loadSessionPhone();
    final friendshipId = incomingFriendshipId(studentId);
    if (phone == null || friendshipId == null) return;
    await FriendsApi.instance.respond(
      phone: phone,
      friendshipId: friendshipId,
      action: 'accept',
    );
    await refreshFriends(pullRemote: true);
  }

  Future<void> declineFriend(String studentId) async {
    final phone = _sessionPhone ?? await AuthSessionStore.loadSessionPhone();
    final friendshipId = incomingFriendshipId(studentId);
    if (phone == null || friendshipId == null) return;
    await FriendsApi.instance.respond(
      phone: phone,
      friendshipId: friendshipId,
      action: 'decline',
    );
    await refreshFriends(pullRemote: true);
  }

  Future<void> removeFriend(String studentId) async {
    final phone = _sessionPhone ?? await AuthSessionStore.loadSessionPhone();
    if (phone == null) {
      _friendIds.remove(studentId);
      _outgoingByPeer.remove(studentId);
      await _persist();
      notifyListeners();
      return;
    }
    await FriendsApi.instance.remove(phone: phone, targetId: studentId);
    await refreshFriends(pullRemote: true);
  }

  Future<void> reportProfileView(String studentId) async {
    if (studentId == currentUserId) return;
    final phone = _sessionPhone ?? await AuthSessionStore.loadSessionPhone();
    if (phone == null) return;
    _sessionPhone = phone;
    await FriendsApi.instance.reportProfileView(
      viewerPhone: phone,
      targetId: studentId,
    );
  }

  StudentMood moodFor(MapStudent student) {
    if (student.isCurrentUser &&
        _moodEmoji != null &&
        _moodLabel != null) {
      return StudentMood(emoji: _moodEmoji!, label: _moodLabel!);
    }
    return moodForStudent(student);
  }

  Future<void> setMyMood(StudentMood mood) async {
    _moodEmoji = mood.emoji;
    _moodLabel = mood.label;
    await _persist();
    await _pushProfileRemote();
    notifyListeners();
  }

  Future<void> saveMyProfile({
    required String displayName,
    required String school,
    required String bio,
    required String grade,
    required List<String> subjects,
    required String cityId,
    String? tagline,
    StudentMood? mood,
  }) async {
    _displayName = displayName.trim();
    _school = school.trim();
    _bio = bio.trim();
    _tagline = tagline?.trim().isEmpty == true ? null : tagline?.trim();
    _cachedGrade = gradeBase(grade);
    _subjects = subjects.take(4).toList();
    _cityId = cityId;
    if (mood != null) {
      _moodEmoji = mood.emoji;
      _moodLabel = mood.label;
    }
    await _persist();
    await _pushProfileRemote();
    notifyListeners();
  }

  Future<void> _pushProfileRemote() async {
    final phone = _sessionPhone ?? await AuthSessionStore.loadSessionPhone();
    if (phone == null) return;
    _sessionPhone = phone;
    await FriendsApi.instance.upsertProfile(
      phone: phone,
      // Unique per phone — never the shared local demo pin id.
      mapId: remoteMapIdForPhone(phone),
      displayName: _displayName ?? '',
      school: _school ?? '',
      bio: _bio ?? '',
      grade: _cachedGrade ?? '',
      cityId: _cityId ?? '',
      subjects: _subjects,
      tagline: _tagline,
      moodEmoji: _moodEmoji,
      moodLabel: _moodLabel,
    );
  }

  /// Stable remote map/profile id derived from E.164 (not the demo pin slug).
  static String remoteMapIdForPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return phone;
    return 'u$digits';
  }

  /// Map pins + profiles with the signed-in learner patched in.
  List<MapStudent> get students {
    return [
      for (final s in mapStudents) resolveStudent(s),
    ];
  }

  MapStudent get me => resolveStudent(
        mapStudents.firstWhere(
          (s) => s.isCurrentUser || s.id == currentUserId,
          orElse: () => mapStudents.first,
        ),
      );

  MapStudent? studentById(String id) {
    final normalized = id.toLowerCase();
    if (normalized == 'me' || normalized == currentUserId) return me;
    for (final s in students) {
      if (s.id == normalized ||
          s.id == id ||
          s.initials.toLowerCase() == normalized) {
        return s;
      }
    }
    final fromDir = _friendDirectory[id] ?? _friendDirectory[normalized];
    if (fromDir != null) return fromDir;
    return mapStudentById(id) ?? mapStudentById(normalized);
  }

  MapStudent resolveStudent(MapStudent base) {
    if (!base.isCurrentUser && base.id != currentUserId) return base;

    final path = PathProgressStore.instance;
    final study = StudyProgressStore.instance;
    final grade = _cachedGrade ?? base.grade;
    final subjects = _subjects.isNotEmpty
        ? _subjects
        : _subjectsFromInterests(_authInterests, const []);
    final name = (_displayName?.trim().isNotEmpty ?? false)
        ? _displayName!.trim()
        : 'Your name';
    final school = (_school?.trim().isNotEmpty ?? false)
        ? _school!.trim()
        : 'Add your school';
    final bio = (_bio?.trim().isNotEmpty ?? false)
        ? _bio!.trim()
        : 'Tell others what you are studying and how they can study with you.';
    final city = selectedCity;
    final location = city?.location ?? base.location;

    return MapStudent(
      id: currentUserId,
      name: name,
      initials: initialsFromName(name),
      grade: gradeBase(grade),
      points: computeLeaderboardPoints(path, study),
      location: location,
      subjects: subjects,
      streak: path.liveStreak,
      avgScore: study.chapterExamsCompleted > 0
          ? _liveAvgScore(study)
          : 0,
      bio: bio,
      school: school,
      isOnline: true,
      isCurrentUser: true,
    );
  }

  String? get myTagline {
    if (_tagline?.trim().isNotEmpty ?? false) return _tagline!.trim();
    return null;
  }

  List<MapStudent> friendsFor(MapStudent student) {
    if (student.isCurrentUser) {
      final seen = <String>{};
      final out = <MapStudent>[];
      for (final id in _friendIds) {
        if (id == currentUserId || id == 'me') continue;
        if (_sessionPhone != null && id == _sessionPhone) continue;
        final s = studentById(id) ??
            _friendDirectory[id] ??
            mapStudentById(id);
        if (s == null || s.isCurrentUser || s.id == currentUserId) continue;
        if (!seen.add(s.id)) continue;
        out.add(s);
      }
      return out;
    }
    return friendsForStudent(student);
  }

  List<MapStudent> mutualFriendsWith(MapStudent student) {
    if (student.isCurrentUser) return const [];
    final theirs = studentFriendIds[student.id]?.toSet() ?? {};
    final mutual = _friendIds.intersection(theirs);
    return [
      for (final id in mutual)
        if (studentById(id) != null) studentById(id)!,
    ];
  }

  List<MapActivityItem> activitiesFor(MapStudent student) {
    if (student.isCurrentUser) return _liveActivities();
    return _peerActivities(student);
  }

  List<MapActivityItem> _liveActivities() {
    final study = StudyProgressStore.instance;
    final path = PathProgressStore.instance;
    final items = <MapActivityItem>[];

    if (path.liveStreak > 0) {
      items.add(
        MapActivityItem(
          id: 'streak',
          kind: MapActivityKind.streak,
          title: '${path.liveStreak}-day Path streak',
          subtitle: 'Keep showing up. Energy regenerates while you rest.',
          timeLabel: 'Today',
          ctaLabel: 'Continue Path',
          ctaRoute: '/the-path',
        ),
      );
    }

    if (path.totalStars > 0) {
      items.add(
        MapActivityItem(
          id: 'stars',
          kind: MapActivityKind.path,
          title: 'Earned ${path.totalStars} Path stars',
          subtitle: '${path.xpWallet} XP in your wallet',
          timeLabel: 'This week',
          ctaLabel: 'Open Path',
          ctaRoute: '/the-path',
        ),
      );
    }

    final examCount = study.chapterExamsCompleted;
    if (examCount > 0) {
      items.add(
        MapActivityItem(
          id: 'exams',
          kind: MapActivityKind.exam,
          title: examCount == 1
              ? 'Passed a chapter exam'
              : 'Passed $examCount chapter exams',
          subtitle: 'Exam wins count toward your subject progress.',
          timeLabel: 'Recently',
          ctaLabel: 'Take exam',
          ctaRoute: '/exams',
        ),
      );
    }

    final noteCount = study.notesCompleted;
    if (noteCount > 0) {
      items.add(
        MapActivityItem(
          id: 'notes',
          kind: MapActivityKind.note,
          title: noteCount == 1
              ? 'Finished a study note'
              : 'Finished $noteCount study notes',
          subtitle: 'Notes you open mark progress on Learn.',
          timeLabel: 'Recently',
          ctaLabel: 'Keep learning',
          ctaRoute: '/study',
        ),
      );
    }

    final deckCount = study.decksCompleted;
    if (deckCount > 0) {
      items.add(
        MapActivityItem(
          id: 'cards',
          kind: MapActivityKind.cards,
          title: deckCount == 1
              ? 'Cleared a flashcard deck'
              : 'Cleared $deckCount flashcard decks',
          subtitle: 'Cards lock in what notes introduce.',
          timeLabel: 'Recently',
          ctaLabel: 'Review cards',
          ctaRoute: '/study',
        ),
      );
    }

    if (items.isEmpty) {
      items.addAll(const [
        MapActivityItem(
          id: 'start-path',
          kind: MapActivityKind.path,
          title: 'Start your first Path level',
          subtitle: 'Earn stars, build a streak, climb the region board.',
          timeLabel: 'Ready when you are',
          ctaLabel: 'Play Path',
          ctaRoute: '/the-path',
        ),
        MapActivityItem(
          id: 'start-notes',
          kind: MapActivityKind.note,
          title: 'Open a chapter note',
          subtitle: 'Your profile activity fills as you study.',
          timeLabel: 'Tip',
          ctaLabel: 'Go to Learn',
          ctaRoute: '/study',
        ),
      ]);
    }

    return items;
  }

  List<MapActivityItem> _peerActivities(MapStudent student) {
    final first = student.name.split(' ').first;
    final subject = student.subjects.isNotEmpty
        ? student.subjects.first
        : 'study';
    return [
      MapActivityItem(
        id: '${student.id}-streak',
        kind: MapActivityKind.streak,
        title: '$first hit a ${student.streak}-day streak',
        subtitle: 'Consistency beats cramming. Cheer them on.',
        timeLabel: 'Today',
        ctaLabel: 'Cheer',
      ),
      MapActivityItem(
        id: '${student.id}-subject',
        kind: MapActivityKind.note,
        title: 'Focused on $subject',
        subtitle: '${student.grade} · avg ${student.avgScore}%',
        timeLabel: 'This week',
        ctaLabel: 'Study together',
        ctaRoute: '/study',
      ),
      MapActivityItem(
        id: '${student.id}-path',
        kind: MapActivityKind.path,
        title: 'Climbing The Path',
        subtitle: '${student.points} profile points · region active',
        timeLabel: 'Recently',
        ctaLabel: 'Open Path',
        ctaRoute: '/the-path',
      ),
    ];
  }

  static List<String> _subjectsFromInterests(
    Set<String> interests,
    List<String> fallback,
  ) {
    if (interests.isEmpty) return fallback;
    final mapped = <String>[];
    for (final interest in interests) {
      final lower = interest.toLowerCase();
      if (lower.contains('math')) {
        mapped.add('Mathematics');
      } else if (lower.contains('phys')) {
        mapped.add('Physics');
      } else if (lower.contains('chem')) {
        mapped.add('Chemistry');
      } else if (lower.contains('bio')) {
        mapped.add('Biology');
      } else if (lower.contains('eng')) {
        mapped.add('English');
      } else if (lower.contains('hist')) {
        mapped.add('History');
      } else if (lower.contains('geo')) {
        mapped.add('Geography');
      } else if (lower.contains('education') || lower.contains('technology')) {
        mapped.add('ICT');
      }
    }
    final unique = <String>{...mapped};
    if (unique.isEmpty) return fallback;
    return unique.take(4).toList();
  }

  static int _liveAvgScore(StudyProgressStore study) {
    final exams = study.chapterExamsCompleted;
    if (exams <= 0) return 0;
    return ((70 * 0.3) + (88 * 0.7)).round().clamp(60, 99);
  }
}

Set<String> _stringSet(dynamic raw) {
  if (raw is! List) return {};
  return {
    for (final e in raw)
      if ('$e'.trim().isNotEmpty) '$e'.trim(),
  };
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return [];
  return [
    for (final e in raw)
      if ('$e'.trim().isNotEmpty) '$e'.trim(),
  ];
}

String initialsFromName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final p = parts.first;
    return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
  }
  return ('${parts.first[0]}${parts.last[0]}').toUpperCase();
}

/// Preset moods the learner can pick on their own profile.
const mapMoodPresets = [
  StudentMood(emoji: '🎯', label: 'Building habits'),
  StudentMood(emoji: '📚', label: 'Deep focus mode'),
  StudentMood(emoji: '⚡', label: 'Exam sprint'),
  StudentMood(emoji: '☕', label: 'Library grind'),
  StudentMood(emoji: '🌱', label: 'Learning foundations'),
  StudentMood(emoji: '🏆', label: 'Matric countdown'),
  StudentMood(emoji: '🤝', label: 'Looking for study buddies'),
  StudentMood(emoji: '✨', label: 'Ready to learn'),
];
