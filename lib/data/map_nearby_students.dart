import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'map_students.dart';

class FeaturedMapStudent {
  const FeaturedMapStudent({
    required this.student,
    required this.displayName,
    required this.city,
    required this.distanceKm,
    required this.subjectTags,
  });

  final MapStudent student;
  final String displayName;
  final String city;
  final double distanceKm;
  final List<SubjectTag> subjectTags;
}

class SubjectTag {
  const SubjectTag({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;
}

class NearbyStudentRow {
  const NearbyStudentRow({
    required this.studentId,
    required this.displayName,
    required this.city,
    required this.tags,
  });

  final String studentId;
  final String displayName;
  final String city;
  final List<SubjectTag> tags;
}

const _displayNameOverrides = {
  'dawit-girma': 'Dawit Girma',
  'hanna-b': 'Hanna Bekele',
  'yonas-alem': 'Yonas Alemu',
};

String displayNameForStudent(MapStudent student) {
  return _displayNameOverrides[student.id] ?? student.name;
}

String cityForStudent(MapStudent student) {
  for (final row in nearbyStudentRowData) {
    if (row.studentId == student.id) return row.city;
  }
  if (student.id == 'yonas-alem') return 'Hawassa';
  return 'Addis Ababa';
}

List<SubjectTag> subjectTagsForStudent(MapStudent student) {
  NearbyStudentRow? row;
  for (final candidate in nearbyStudentRowData) {
    if (candidate.studentId == student.id) {
      row = candidate;
      break;
    }
  }
  if (row != null && row.tags.isNotEmpty) return row.tags;

  if (student.id == 'dawit-girma') {
    return const [
      SubjectTag(
        label: 'Maths 95%',
        color: AppColors.teal,
        background: AppColors.tealSoft,
      ),
      SubjectTag(
        label: 'Physics',
        color: AppColors.info,
        background: AppColors.infoSoft,
      ),
    ];
  }

  return [
    for (final subject in student.subjects.take(2))
      SubjectTag(
        label: subject == 'Mathematics' ? 'Maths' : subject,
        color: AppColors.teal,
        background: AppColors.tealSoft,
      ),
  ];
}

double distanceKmForStudent(MapStudent student) {
  MapStudent? currentUser;
  for (final s in mapStudents) {
    if (s.isCurrentUser) {
      currentUser = s;
      break;
    }
  }
  if (currentUser == null || currentUser.id == student.id) return 0;
  if (student.id == 'yonas-alem') return 275;
  return 0.8 + (student.points % 7) * 0.15;
}

FeaturedMapStudent featuredMapStudentFor(MapStudent student) {
  return FeaturedMapStudent(
    student: student,
    displayName: displayNameForStudent(student),
    city: cityForStudent(student),
    distanceKm: distanceKmForStudent(student),
    subjectTags: subjectTagsForStudent(student),
  );
}

const nearbyStudentRowData = [
  NearbyStudentRow(
    studentId: 'hanna-b',
    displayName: 'Hanna Bekele',
    city: 'Addis Ababa',
    tags: [
      SubjectTag(
        label: 'Chemistry',
        color: AppColors.teal,
        background: AppColors.tealSoft,
      ),
      SubjectTag(
        label: 'Biology',
        color: AppColors.teal,
        background: AppColors.tealSoft,
      ),
    ],
  ),
  NearbyStudentRow(
    studentId: 'yonas-alem',
    displayName: 'Yonas Alemu',
    city: 'Hawassa',
    tags: [
      SubjectTag(
        label: 'Maths',
        color: AppColors.accentText,
        background: AppColors.accentSoft,
      ),
      SubjectTag(
        label: 'Physics',
        color: AppColors.info,
        background: AppColors.infoSoft,
      ),
    ],
  ),
];

List<({MapStudent student, NearbyStudentRow row})> resolvedNearbyRows({
  String? excludeStudentId,
}) {
  return [
    for (final row in nearbyStudentRowData)
      if (row.studentId != excludeStudentId &&
          mapStudentById(row.studentId) != null)
        (student: mapStudentById(row.studentId)!, row: row),
  ];
}

List<({MapStudent student, NearbyStudentRow row})> nearbyRowsForStudent(
  MapStudent student,
) {
  final fromData = resolvedNearbyRows(excludeStudentId: student.id);
  if (fromData.isNotEmpty) return fromData;

  return [
    for (final other in mapStudents)
      if (other.id != student.id && !other.isCurrentUser)
        (
          student: other,
          row: NearbyStudentRow(
            studentId: other.id,
            displayName: displayNameForStudent(other),
            city: cityForStudent(other),
            tags: subjectTagsForStudent(other),
          ),
        ),
  ].take(4).toList();
}

int mapOnlineCount() => mapStudents.where((s) => s.isOnline).length;
