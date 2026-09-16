import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/battle_setup_data.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/birthdate_onboarding_screen.dart';
import '../../features/auth/grade_onboarding_screen.dart';
import '../../features/auth/interests_onboarding_screen.dart';
import '../../features/auth/name_onboarding_screen.dart';
import '../../features/auth/otp_verify_screen.dart';
import '../../features/auth/phone_login_screen.dart';
import '../../features/path/path_level_play_screen.dart';
import '../../features/path/path_map_screen.dart';
import '../../features/battle/battle_screen.dart';
import '../../features/battle/battle_waiting_room_screen.dart';
import '../../features/battle/create_battle_screen.dart';
import '../../features/community/community_screen.dart';
import '../../features/home/daily_streak_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/leaderboard_screen.dart';
import '../../features/home/placeholder_screens.dart';
import '../../features/map/map_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/chats_inbox_screen.dart';
import '../../features/map/edit_map_profile_screen.dart';
import '../../features/map/student_map_profile_screen.dart';
import '../../features/map/student_profile_screen.dart';
import '../../data/map_profile_store.dart';
import '../../data/map_students.dart';
import '../../data/exam_questions.dart';
import '../../data/exam_type.dart';
import '../../data/flashcard_data.dart';
import '../../features/exam/exam_screen.dart';
import '../../features/exam/exams_hub_screen.dart';
import '../../features/flashcards/flashcard_screen.dart';
import '../../data/note_assets.dart';
import '../../features/notes/note_reader_screen.dart';
import '../../features/notes/notes_screen.dart';
import '../../features/notes/subject_chapters_sheet.dart';
import '../../features/notes/subject_exam_options_sheet.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/subscription/subscription_screen.dart';
import '../../features/subscription/subscription_walkthrough_screen.dart';
import '../../features/referral/invite_friends_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/account_pages.dart';
import '../../data/app_support.dart';
import '../../data/study_subjects.dart';
import '../../widgets/navigation/app_bottom_nav.dart';

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}

StudySubject? _subjectFromRoute(GoRouterState state) {
  final name = state.pathParameters['name'];
  if (name == null) return null;
  return studySubjectByName(Uri.decodeComponent(name));
}

Page<void> _noAnimPage({
  required GoRouterState state,
  required Widget child,
}) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    child: child,
  );
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;
      final isSplash = path == '/splash';
      final isAuthRoute = path == '/login' || path == '/otp';
      final isOnboarding = path.startsWith('/onboarding');

      if (isSplash) return null;

      // Don't redirect until local session is loaded.
      if (!auth.isHydrated) return null;

      if (!auth.otpVerified && !auth.isAuthenticated) {
        if (!isAuthRoute) return '/login';
        if (path == '/otp' && auth.pendingPhone == null) return '/login';
        return null;
      }

      if (auth.needsOnboarding) {
        if (isAuthRoute || !isOnboarding) return auth.onboardingPath;
        if (path == '/onboarding/grade' &&
            (auth.fullName == null || auth.fullName!.trim().isEmpty)) {
          return '/onboarding/name';
        }
        if (path == '/onboarding/birthdate' &&
            (auth.fullName == null ||
                auth.fullName!.trim().isEmpty ||
                auth.grade == null)) {
          return auth.onboardingPath;
        }
        if (path == '/onboarding/interests' &&
            (auth.fullName == null ||
                auth.fullName!.trim().isEmpty ||
                auth.grade == null ||
                auth.birthdate == null)) {
          return auth.onboardingPath;
        }
        return null;
      }

      if (auth.isAuthenticated && (isAuthRoute || isOnboarding)) {
        return '/home';
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Page not found'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No route for ${state.uri}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/splash',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _noAnimPage(
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _noAnimPage(
          state: state,
          child: const PhoneLoginScreen(),
        ),
      ),
      GoRoute(
        path: '/otp',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _noAnimPage(
          state: state,
          child: const OtpVerifyScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding/name',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _noAnimPage(
          state: state,
          child: const NameOnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding/grade',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _noAnimPage(
          state: state,
          child: const GradeOnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding/birthdate',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _noAnimPage(
          state: state,
          child: const BirthdateOnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding/interests',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _noAnimPage(
          state: state,
          child: const InterestsOnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SimpleDetailScreen(
          title: 'Notifications',
          subtitle: 'No new notifications',
        ),
      ),
      GoRoute(
        path: '/streak',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DailyStreakScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) => '/home/leaderboard',
      ),
      GoRoute(
        path: '/chats',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ChatsInboxScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final raw = state.pathParameters['id'] ?? '';
          final id = Uri.decodeComponent(raw);
          final existing =
              MapProfileStore.instance.studentById(id) ?? mapStudentById(id);
          final student = existing ??
              MapStudent(
                id: id,
                name: id.startsWith('+') ? id : 'Student',
                initials: _chatInitials(id),
                grade: '',
                points: 0,
                location: mapDefaultCenter,
                subjects: const [],
                streak: 0,
                avgScore: 0,
              );
          return ChatScreen(student: student);
        },
      ),
      GoRoute(
        path: '/student/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final raw = state.pathParameters['id'] ?? '';
          final id = Uri.decodeComponent(raw);
          final existing =
              MapProfileStore.instance.studentById(id) ?? mapStudentById(id);
          if (existing != null) {
            return StudentProfileScreen(student: existing);
          }
          // Phone / directory peers: show a lightweight profile shell.
          if (id.startsWith('+') || id.startsWith('u')) {
            return StudentProfileScreen(
              student: MapStudent(
                id: id,
                name: id.startsWith('+') ? id : 'Student',
                initials: _chatInitials(id),
                grade: '',
                points: 0,
                location: mapDefaultCenter,
                subjects: const [],
                streak: 0,
                avgScore: 0,
              ),
            );
          }
          return SimpleDetailScreen(
            title: state.extra as String? ?? 'Student Profile',
            subtitle: 'Student not found',
          );
        },
        routes: [
          GoRoute(
            path: 'full',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) {
              final student = MapProfileStore.instance
                      .studentById(state.pathParameters['id']!) ??
                  mapStudentById(state.pathParameters['id']!);
              if (student != null) {
                return StudentProfileScreen(student: student);
              }
              return const SimpleDetailScreen(
                title: 'Student Profile',
                subtitle: 'Student not found',
              );
            },
          ),
          GoRoute(
            path: 'map',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) {
              final student = MapProfileStore.instance
                      .studentById(state.pathParameters['id']!) ??
                  mapStudentById(state.pathParameters['id']!);
              if (student != null) {
                return StudentMapProfileScreen(student: student);
              }
              return const SimpleDetailScreen(
                title: 'Student Map',
                subtitle: 'Student not found',
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/the-path',
        name: 'thePath',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PathMapScreen(),
        routes: [
          GoRoute(
            path: 'level/:id',
            name: 'thePathLevel',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => PathLevelPlayScreen(
              levelId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      // Alias in case older builds still navigate to /path
      GoRoute(
        path: '/path',
        redirect: (context, state) => '/the-path',
      ),
      GoRoute(
        path: '/battle',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BattleScreen(),
      ),
      GoRoute(
        path: '/battle/create',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CreateBattleScreen(),
      ),
      GoRoute(
        path: '/battle/waiting',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final setup = state.extra;
          if (setup is BattleSetup) {
            return BattleWaitingRoomScreen(setup: setup);
          }
          return const CreateBattleScreen();
        },
      ),
      GoRoute(
        path: '/study/subject/:name',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final subject = _subjectFromRoute(state);
          if (subject == null) {
            return const SimpleDetailScreen(
              title: 'Subject',
              subtitle: 'Subject not found',
            );
          }
          final chapterExam =
              state.uri.queryParameters['mode'] == 'chapter-exam';
          return SubjectChaptersSheet(
            subject: subject,
            isChapterExam: chapterExam,
          );
        },
        routes: [
          GoRoute(
            path: 'exams',
            builder: (context, state) {
              final subject = _subjectFromRoute(state);
              if (subject == null) {
                return const SimpleDetailScreen(
                  title: 'Exams',
                  subtitle: 'Subject not found',
                );
              }
              final typeName = state.uri.queryParameters['type'];
              ExamType? initialType;
              if (typeName != null) {
                for (final t in ExamType.values) {
                  if (t.name == typeName) {
                    initialType = t;
                    break;
                  }
                }
              }
              return SubjectExamOptionsSheet(
                subject: subject,
                showBackButton: true,
                initialType: initialType,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/content/:type',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final type = state.pathParameters['type'];
          final extra = state.extra;

          if (extra is FlashcardSessionArgs) {
            return FlashcardScreen(args: extra);
          }

          if (extra is NoteSessionArgs) {
            return NoteReaderScreen(args: extra);
          }

          if (type == 'exam') {
            final args = extra is ExamSessionArgs
                ? extra
                : ExamSessionArgs.fromExtra(extra);
            if (args != null) return ExamScreen(args: args);
            return const SimpleDetailScreen(
              title: 'Exam',
              subtitle: 'Select an exam to begin',
            );
          }

          if (type == 'flashcards') {
            return const SimpleDetailScreen(
              title: 'Flashcards',
              subtitle: 'Select a chapter to start studying',
            );
          }

          final title = extra is String ? extra : 'Content';
          return SimpleDetailScreen(
            title: title,
            subtitle: 'Opening $type content',
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) {
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: Scaffold(
              backgroundColor: AppColors.bgBase,
              extendBody: true,
              body: navigationShell,
              bottomNavigationBar:
                  AppBottomNav(navigationShell: navigationShell),
            ),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'leaderboard',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const LeaderboardScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/study',
                builder: (context, state) => const NotesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exams',
                builder: (context, state) => const ExamsHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapScreen(),
                routes: [
                  GoRoute(
                    path: 'edit-profile',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const EditMapProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (context, state) => const CommunityScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/subscription',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SubscriptionWalkthroughScreen(),
      ),
      GoRoute(
        path: '/subscription/plans',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/invite',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const InviteFriendsScreen(),
      ),
      GoRoute(
        path: '/profile',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/account/terms',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LegalDocumentScreen(
          title: AppLegalCopy.termsTitle,
          body: AppLegalCopy.termsBody,
        ),
      ),
      GoRoute(
        path: '/account/privacy',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LegalDocumentScreen(
          title: AppLegalCopy.privacyTitle,
          body: AppLegalCopy.privacyBody,
        ),
      ),
      GoRoute(
        path: '/account/feedback',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FeedbackScreen(),
      ),
      GoRoute(
        path: '/account/support',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/account/social',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SocialMediaScreen(),
      ),
    ],
  );
});

String _chatInitials(String id) {
  final cleaned = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (cleaned.length >= 2) return cleaned.substring(0, 2).toUpperCase();
  if (cleaned.isNotEmpty) return cleaned.toUpperCase();
  return '?';
}
