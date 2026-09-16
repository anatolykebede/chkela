import '../core/models/content_item.dart';
import '../core/models/content_type.dart';

const subjects = [
  'All',
  'Mathematics',
  'Physics',
  'Chemistry',
  'Biology',
  'English',
];

const recentContent = [
  ContentItem(
    id: '1',
    title: 'Quadratic Equations',
    subtitle: 'Chapter 4 · 12 pages',
    type: ContentType.notes,
    subject: 'Mathematics',
    isBookmarked: true,
  ),
  ContentItem(
    id: '2',
    title: 'Newton\'s Laws of Motion',
    subtitle: 'Flashcards · 15 cards',
    type: ContentType.flashcard,
    subject: 'Physics',
    progress: 0.65,
  ),
  ContentItem(
    id: '3',
    title: '2024 National Exam Paper',
    subtitle: 'Chemistry · 40 questions',
    type: ContentType.exam,
    subject: 'Chemistry',
  ),
  ContentItem(
    id: '4',
    title: 'Cell Structure Explained',
    subtitle: 'Flashcards · 12 cards',
    type: ContentType.flashcard,
    subject: 'Biology',
    progress: 0.3,
  ),
];

const continueLearning = ContentItem(
  id: 'continue',
  title: 'Organic Chemistry Basics',
  subtitle: 'Chapter 7 · 45% complete',
  type: ContentType.notes,
  subject: 'Chemistry',
  progress: 0.45,
);

const notesContent = [
  ContentItem(
    id: 'n1',
    title: 'Trigonometry Fundamentals',
    subtitle: 'Chapter 2 · 8 pages',
    type: ContentType.notes,
    subject: 'Mathematics',
    isBookmarked: true,
  ),
  ContentItem(
    id: 'n2',
    title: 'Electromagnetic Waves',
    subtitle: 'Chapter 5 · 15 pages',
    type: ContentType.notes,
    subject: 'Physics',
  ),
  ContentItem(
    id: 'n3',
    title: 'Essay Writing Techniques',
    subtitle: 'Chapter 1 · 10 pages',
    type: ContentType.notes,
    subject: 'English',
  ),
  ContentItem(
    id: 'n4',
    title: 'Genetics & Heredity',
    subtitle: 'Chapter 3 · 20 pages',
    type: ContentType.notes,
    subject: 'Biology',
    isBookmarked: true,
  ),
];

class CommunityPost {
  const CommunityPost({
    required this.author,
    required this.subject,
    required this.content,
    required this.replies,
    required this.timeAgo,
  });

  final String author;
  final String subject;
  final String content;
  final int replies;
  final String timeAgo;
}

const communityPosts = [
  CommunityPost(
    author: 'Sarah M.',
    subject: 'Mathematics',
    content:
        'Can someone explain the difference between permutation and combination?',
    replies: 12,
    timeAgo: '2h ago',
  ),
  CommunityPost(
    author: 'James K.',
    subject: 'Physics',
    content:
        'Just finished the optics chapter — the lens formula finally clicked!',
    replies: 5,
    timeAgo: '4h ago',
  ),
  CommunityPost(
    author: 'Amina T.',
    subject: 'Chemistry',
    content:
        'Study group for organic chemistry this Saturday at 3 PM. Who\'s in?',
    replies: 23,
    timeAgo: '6h ago',
  ),
];
