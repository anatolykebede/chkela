import 'package:latlong2/latlong.dart';

const mapDefaultCenter = LatLng(9.0320, 38.7469);
const mapDefaultZoom = 13.0;

const mapMarkerBaseWidth = 52.0;
const mapMarkerBaseHeight = 58.0;

double mapMarkerScaleForZoom(double zoom, {double minZoom = 3.5}) {
  if (zoom >= mapDefaultZoom) return 1.0;
  const minScale = 0.2;
  final t = ((zoom - minZoom) / (mapDefaultZoom - minZoom)).clamp(0.0, 1.0);
  return minScale + (1 - minScale) * t;
}

const eastAfricaSouthWest = LatLng(-12.0, 28.5);
const eastAfricaNorthEast = LatLng(18.0, 51.8);

class MapStudent {
  const MapStudent({
    required this.id,
    required this.name,
    required this.initials,
    required this.grade,
    required this.points,
    required this.location,
    required this.subjects,
    required this.streak,
    required this.avgScore,
    this.bio,
    this.school = 'Addis Ababa Secondary School',
    this.isOnline = false,
    this.isCurrentUser = false,
  });

  final String id;
  final String name;
  final String initials;
  final String grade;
  final int points;
  final LatLng location;
  final List<String> subjects;
  final int streak;
  final int avgScore;
  final String? bio;
  final String school;
  final bool isOnline;
  final bool isCurrentUser;

  String get gradeShort => grade.replaceAll('Grade ', 'Gr ');
}

const mapStudents = [
  MapStudent(
    id: 'hanna-b',
    name: 'Hanna B.',
    initials: 'HB',
    grade: 'Grade 10',
    points: 4820,
    location: LatLng(9.0358, 38.7512),
    subjects: ['Mathematics', 'Physics', 'Chemistry'],
    streak: 21,
    avgScore: 92,
    bio: 'Focused on STEM prep. Happy to study together!',
    isOnline: true,
  ),
  MapStudent(
    id: 'daniel-m',
    name: 'Daniel M.',
    initials: 'DM',
    grade: 'Grade 10',
    points: 4510,
    location: LatLng(9.0284, 38.7421),
    subjects: ['Biology', 'Chemistry', 'English'],
    streak: 14,
    avgScore: 88,
    bio: 'Bio & chem enthusiast. Usually at Bole library.',
    isOnline: true,
  ),
  MapStudent(
    id: 'meron-a',
    name: 'Meron A.',
    initials: 'MA',
    grade: 'Grade 10',
    points: 4380,
    location: LatLng(9.0391, 38.7388),
    subjects: ['Mathematics', 'English', 'Physics'],
    streak: 18,
    avgScore: 90,
    bio: 'Exam season mode. Ask me about quadratic equations.',
    isOnline: false,
  ),
  MapStudent(
    id: 'selam-tadesse',
    name: 'Selam Tadesse',
    initials: 'ST',
    grade: 'Grade 10',
    points: 4150,
    location: LatLng(9.0312, 38.7495),
    subjects: ['Mathematics', 'Biology', 'Chemistry'],
    streak: 14,
    avgScore: 87,
    bio: 'Building a daily study habit one chapter at a time.',
    isOnline: true,
    isCurrentUser: true,
  ),
  MapStudent(
    id: 'yosef-k',
    name: 'Yosef K.',
    initials: 'YK',
    grade: 'Grade 11',
    points: 3920,
    location: LatLng(9.0267, 38.7553),
    subjects: ['Physics', 'Mathematics', 'Chemistry'],
    streak: 9,
    avgScore: 85,
    bio: 'Grade 11 physics — always up for problem sets.',
    isOnline: false,
  ),
  MapStudent(
    id: 'tigist-h',
    name: 'Tigist H.',
    initials: 'TH',
    grade: 'Grade 9',
    points: 3680,
    location: LatLng(9.0375, 38.7440),
    subjects: ['English', 'Mathematics', 'Biology'],
    streak: 11,
    avgScore: 83,
    bio: 'New to Chkela — learning algebra foundations.',
    isOnline: true,
  ),
  MapStudent(
    id: 'abenezer-l',
    name: 'Abenezer L.',
    initials: 'AL',
    grade: 'Grade 12',
    points: 5100,
    location: LatLng(9.0245, 38.7488),
    subjects: ['Chemistry', 'Mathematics', 'Biology'],
    streak: 28,
    avgScore: 94,
    bio: 'Matric prep — national exam in 3 months.',
    isOnline: true,
  ),
  MapStudent(
    id: 'ruth-n',
    name: 'Ruth N.',
    initials: 'RN',
    grade: 'Grade 10',
    points: 4010,
    location: LatLng(9.0338, 38.7410),
    subjects: ['English', 'Biology', 'Chemistry'],
    streak: 7,
    avgScore: 86,
    bio: 'English lit fan · always up for study groups.',
    isOnline: false,
  ),
  MapStudent(
    id: 'dawit-girma',
    name: 'Dawit G.',
    initials: 'DG',
    grade: 'Grade 12',
    points: 4820,
    location: LatLng(9.0345, 38.7520),
    subjects: ['Mathematics', 'Physics'],
    streak: 21,
    avgScore: 92,
    bio: 'Top of the region in Maths — always up for a challenge.',
    isOnline: true,
  ),
  MapStudent(
    id: 'yonas-alem',
    name: 'Yonas A.',
    initials: 'YA',
    grade: 'Grade 11',
    points: 3890,
    location: LatLng(7.0621, 38.4764),
    subjects: ['Mathematics', 'Physics'],
    streak: 12,
    avgScore: 88,
    bio: 'Hawassa-based · physics problem sets.',
    isOnline: true,
  ),
];

MapStudent? mapStudentById(String id) {
  final normalized = id.toLowerCase();
  for (final student in mapStudents) {
    if (student.id == normalized ||
        student.initials.toLowerCase() == normalized) {
      return student;
    }
  }
  return null;
}
