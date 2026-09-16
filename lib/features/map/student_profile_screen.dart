import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/friends_api.dart';
import '../../data/map_activity.dart';
import '../../data/map_profile_store.dart';
import '../../data/map_students.dart';
import '../../data/map_student_social.dart';
import '../../data/path_progress_store.dart';
import '../../data/study_progress_store.dart';
import '../../widgets/common/progress_bar.dart';
import '../auth/auth_provider.dart';
import '../profile/full_profile_chrome.dart';
import 'student_profile_helpers.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({
    super.key,
    required this.student,
  });

  final MapStudent student;

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  int _tab = 0;

  static const _tabs = [
    'Activity',
    'Progress',
    'Subjects',
    'Friends',
    'About',
  ];

  MapStudent get student => widget.student;

  @override
  void initState() {
    super.initState();
    if (!student.isCurrentUser) {
      MapProfileStore.instance.reportProfileView(student.id);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.bgElevated,
      ),
    );
  }

  void _onSendMessage() {
    final store = MapProfileStore.instance;
    if (!store.canMessage(student.id)) {
      _showSnack(
        'Add ${student.name.split(' ').first} as a friend to message them.',
      );
      return;
    }
    context.push('/chat/${Uri.encodeComponent(student.id)}');
  }

  void _onToggleFriend() async {
    final store = MapProfileStore.instance;
    final before = store.relationWith(student.id);
    await store.toggleFriend(student.id);
    final after = store.relationWith(student.id);
    final first = student.name.split(' ').first;
    final message = switch (after) {
      FriendRelationStatus.friends when before == FriendRelationStatus.incoming =>
        'You are now friends with $first',
      FriendRelationStatus.friends => 'You are now friends with $first',
      FriendRelationStatus.outgoing => 'Friend request sent to $first',
      FriendRelationStatus.none when before == FriendRelationStatus.friends =>
        'Removed $first from friends',
      FriendRelationStatus.none when before == FriendRelationStatus.outgoing =>
        'Cancelled request to $first',
      FriendRelationStatus.none => 'Updated friendship with $first',
      FriendRelationStatus.incoming => 'Friend request from $first',
    };
    _showSnack(message);
  }

  void _onDeclineFriend() async {
    await MapProfileStore.instance.declineFriend(student.id);
    _showSnack('Declined ${student.name.split(' ').first}\'s request');
  }

  void _onShareProfile() {
    _showSnack(
      'Profile link copied. Share ${student.name.split(' ').first}\'s profile',
    );
  }

  void _onActivityTap(MapActivityItem item) {
    if (item.kind == MapActivityKind.social || item.ctaLabel == 'Cheer') {
      _showSnack('You cheered ${student.name.split(' ').first} 🎉');
      return;
    }
    final route = item.ctaRoute;
    if (route == null || route.isEmpty) return;
    context.push(route);
  }

  Future<void> _pickMood() async {
    final store = MapProfileStore.instance;
    final current = store.moodFor(store.resolveStudent(student));
    final picked = await showModalBottomSheet<StudentMood>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      builder: (context) => _MoodPickerSheet(current: current),
    );
    if (picked == null) return;
    await store.setMyMood(picked);
    _showSnack('Mood updated: ${picked.emoji} ${picked.label}');
  }

  void _openStudentProfile(MapStudent friend) {
    context.push('/student/${friend.id}/full');
  }

  void _showFriendsListSheet({
    required String title,
    required List<MapStudent> users,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _FriendsListSheet(
        title: title,
        users: users,
        onTapUser: (user) {
          Navigator.pop(sheetContext);
          _openStudentProfile(user);
        },
      ),
    );
  }

  List<ProfileActionSpec> _actionsFor({
    required MapStudent live,
    required FriendRelationStatus relation,
    required StudentProfileStyle style,
  }) {
    if (live.isCurrentUser) {
      return [
        ProfileActionSpec(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Message',
          onTap: () => context.push('/chats'),
        ),
        ProfileActionSpec(
          icon: Icons.emoji_emotions_outlined,
          label: 'Mood',
          onTap: _pickMood,
        ),
        ProfileActionSpec(
          icon: Icons.map_outlined,
          label: 'Map',
          onTap: () => context.push('/student/${live.id}/map'),
        ),
        ProfileActionSpec(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: _onShareProfile,
        ),
        ProfileActionSpec(
          icon: Icons.more_horiz_rounded,
          label: 'More',
          onTap: () => setState(() => _tab = 4),
        ),
      ];
    }

    final friendAction = switch (relation) {
      FriendRelationStatus.incoming => ProfileActionSpec(
          icon: Icons.check_circle_outline,
          label: 'Accept',
          onTap: _onToggleFriend,
        ),
      FriendRelationStatus.friends => ProfileActionSpec(
          icon: Icons.check_circle_outline,
          label: 'Friends',
          onTap: _onToggleFriend,
        ),
      FriendRelationStatus.outgoing => ProfileActionSpec(
          icon: Icons.hourglass_top_rounded,
          label: 'Pending',
          onTap: _onToggleFriend,
        ),
      FriendRelationStatus.none => ProfileActionSpec(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Add',
          onTap: _onToggleFriend,
        ),
    };

    return [
      ProfileActionSpec(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Message',
        onTap: _onSendMessage,
      ),
      friendAction,
      if (relation == FriendRelationStatus.incoming)
        ProfileActionSpec(
          icon: Icons.close_rounded,
          label: 'Decline',
          onTap: _onDeclineFriend,
        )
      else
        ProfileActionSpec(
          icon: Icons.map_outlined,
          label: 'Map',
          onTap: () => context.push('/student/${live.id}/map'),
        ),
      ProfileActionSpec(
        icon: Icons.share_outlined,
        label: 'Share',
        onTap: _onShareProfile,
      ),
      ProfileActionSpec(
        icon: Icons.more_horiz_rounded,
        label: 'More',
        onTap: () => setState(() => _tab = 4),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return ListenableBuilder(
      listenable: Listenable.merge([
        MapProfileStore.instance,
        StudyProgressStore.instance,
      ]),
      builder: (context, _) {
        final store = MapProfileStore.instance;
        final live = store.resolveStudent(student);
        final style = profileStyleFor(
          live,
          customTagline: live.isCurrentUser ? store.myTagline : null,
        );
        final badges = profileBadgesFor(live);
        final rank = mapStudentRegionRank(live);
        final mood = store.moodFor(live);
        final bio = live.bio ?? defaultBioFor(live);
        final friends = store.friendsFor(live);
        final mutualFriends = store.mutualFriendsWith(live);
        final comments = commentsForStudent(live);
        final activities = store.activitiesFor(live);
        final study = StudyProgressStore.instance;
        final path = PathProgressStore.instance;
        final relation = live.isCurrentUser
            ? FriendRelationStatus.none
            : store.relationWith(live.id);
        final username = FullProfileChrome.usernameFromName(live.name);
        final status = live.isOnline
            ? 'online'
            : '${live.grade} · ${live.school}';
        final phoneLabel = live.isCurrentUser && auth.phoneE164 != null
            ? AuthNotifier.displayPhone(auth.phoneE164!)
            : null;

        return Scaffold(
          backgroundColor: AppColors.bgBase,
          body: SafeArea(
            child: Column(
              children: [
                ProfileTopBar(
                  onBack: () => context.pop(),
                  onEdit: live.isCurrentUser
                      ? () => context.push('/map/edit-profile')
                      : null,
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      if (live.isCurrentUser &&
                          store.incomingRequestCount > 0) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.tealSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '${store.incomingRequestCount} friend request${store.incomingRequestCount == 1 ? '' : 's'} waiting',
                              style: HomeTextStyles.bodySmall.copyWith(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Center(
                        child: ProfileAvatarHero(
                          initials: live.initials,
                          isOnline: live.isOnline,
                          accent: style.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        live.name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ProfileActionStrip(
                        actions: _actionsFor(
                          live: live,
                          relation: relation,
                          style: style,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ProfileInfoCard(
                        rows: [
                          if (phoneLabel != null)
                            ProfileInfoRow(
                              label: 'mobile',
                              value: phoneLabel,
                              valueColor: FullProfileChrome.actionBlue,
                            ),
                          ProfileInfoRow(
                            label: 'username',
                            value: username,
                            valueColor: FullProfileChrome.actionBlue,
                            trailing: Icon(
                              Icons.qr_code_2_rounded,
                              size: 22,
                              color: FullProfileChrome.actionBlue
                                  .withValues(alpha: 0.9),
                            ),
                            onTap: () => _showSnack('Chkela ID: $username'),
                          ),
                          ProfileInfoRow(
                            label: 'bio',
                            value: bio,
                            onTap: live.isCurrentUser
                                ? () => context.push('/map/edit-profile')
                                : null,
                          ),
                          ProfileInfoRow(
                            label: 'mood',
                            value: '${mood.emoji} ${mood.label}',
                            onTap: live.isCurrentUser ? _pickMood : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ProfileContentTabs(
                        tabs: _tabs,
                        selectedIndex: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildTabBody(
                          tab: _tab,
                          live: live,
                          style: style,
                          badges: badges,
                          rank: rank,
                          friends: friends,
                          mutualFriends: mutualFriends,
                          comments: comments,
                          activities: activities,
                          study: study,
                          path: path,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabBody({
    required int tab,
    required MapStudent live,
    required StudentProfileStyle style,
    required List<ProfileBadge> badges,
    required int rank,
    required List<MapStudent> friends,
    required List<MapStudent> mutualFriends,
    required List<ProfileComment> comments,
    required List<MapActivityItem> activities,
    required StudyProgressStore study,
    required PathProgressStore path,
  }) {
    switch (tab) {
      case 0:
        return Column(
          children: [
            if (activities.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: FullProfileChrome.cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'No recent activity',
                  textAlign: TextAlign.center,
                  style: HomeTextStyles.bodySmall,
                ),
              )
            else
              ...activities.map(
                (activity) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ActivityTile(
                    activity: activity,
                    onTap: () => _onActivityTap(activity),
                  ),
                ),
              ),
            if (comments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('COMMENTS', style: HomeTextStyles.sectionLabel),
              ),
              const SizedBox(height: 10),
              ...comments.map(
                (comment) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CommentTile(comment: comment),
                ),
              ),
            ],
          ],
        );
      case 1:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Points',
                    value: '${live.points}',
                    icon: Icons.bolt,
                    color: AppColors.amber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: 'Streak',
                    value: '${live.streak}d',
                    icon: Icons.local_fire_department_outlined,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: live.isCurrentUser ? 'Path XP' : 'Avg score',
                    value: live.isCurrentUser
                        ? '${path.xpWallet}'
                        : '${live.avgScore}%',
                    icon: Icons.trending_up,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (live.isCurrentUser) ...[
              _ProgressCard(
                label: 'Notes finished',
                value: '${study.notesCompleted}',
                progress: (study.notesCompleted / 12).clamp(0.0, 1.0),
                accent: style.accent,
              ),
              const SizedBox(height: 8),
              _ProgressCard(
                label: 'Flashcard decks',
                value: '${study.decksCompleted}',
                progress: (study.decksCompleted / 8).clamp(0.0, 1.0),
                accent: style.accent,
              ),
              const SizedBox(height: 8),
              _ProgressCard(
                label: 'Chapter exams passed',
                value: '${study.chapterExamsCompleted}',
                progress: (study.chapterExamsCompleted / 6).clamp(0.0, 1.0),
                accent: style.accent,
              ),
              const SizedBox(height: 8),
              _ProgressCard(
                label: 'Path stars',
                value: '${path.totalStars}',
                progress: (path.totalStars / 30).clamp(0.0, 1.0),
                accent: style.accent,
              ),
            ] else ...[
              _ProgressCard(
                label: 'Weekly goal',
                value: '${(live.streak * 1.2).round()} / 20 hrs',
                progress: (live.streak / 20).clamp(0.0, 1.0),
                accent: style.accent,
              ),
              const SizedBox(height: 8),
              _ProgressCard(
                label: 'Subjects active',
                value: '${live.subjects.length} of 5',
                progress: live.subjects.length / 5,
                accent: style.accent,
              ),
            ],
            const SizedBox(height: 12),
            Text('ACHIEVEMENTS', style: HomeTextStyles.sectionLabel),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < badges.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _BadgeChip(badge: badges[i]),
                  ],
                ],
              ),
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            for (final subject in live.subjects)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SubjectRow(subject: subject),
              ),
          ],
        );
      case 3:
        return Column(
          children: [
            if (!live.isCurrentUser)
              _FriendCountButton(
                label: 'Mutual friends',
                count: mutualFriends.length,
                onTap: () => _showFriendsListSheet(
                  title: 'Mutual friends',
                  users: mutualFriends,
                ),
              ),
            if (!live.isCurrentUser) const SizedBox(height: 10),
            _FriendCountButton(
              label: 'Friends',
              count: friends.length,
              onTap: () => _showFriendsListSheet(
                title: 'Friends',
                users: friends,
              ),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HighlightCard(
              message: style.highlight,
              accent: style.accent,
              accentSoft: style.accentSoft,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FullProfileChrome.cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'School',
                    style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    live.school,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Region rank',
                    style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#$rank in region',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '© Chkela',
              textAlign: TextAlign.center,
              style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
            ),
          ],
        );
    }
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.message,
    required this.accent,
    required this.accentSoft,
  });

  final String message;
  final Color accent;
  final Color accentSoft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_awesome_outlined, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHAT MAKES THEM SPECIAL',
                  style: HomeTextStyles.sectionLabel.copyWith(
                    color: accent.withValues(alpha: 0.85),
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: HomeTextStyles.bodySmall.copyWith(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendCountButton extends StatelessWidget {
  const _FriendCountButton({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
              ),
            ),
            Text(
              '$count',
              style: HomeTextStyles.statValue.copyWith(fontSize: 18),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsListSheet extends StatelessWidget {
  const _FriendsListSheet({
    required this.title,
    required this.users,
    required this.onTapUser,
  });

  final String title;
  final List<MapStudent> users;
  final ValueChanged<MapStudent> onTapUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgOverlay,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: HomeTextStyles.sectionLabel,
                    ),
                  ),
                  Text(
                    '${users.length}',
                    style: HomeTextStyles.badge.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: users.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      child: Text(
                        'No $title yet.',
                        style: HomeTextStyles.bodySmall,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _FriendListTile(
                          user: users[index],
                          onTap: () => onTapUser(users[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendListTile extends StatelessWidget {
  const _FriendListTile({
    required this.user,
    required this.onTap,
  });

  final MapStudent user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = profileStyleFor(user);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: style.accentSoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: style.accent.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  user.initials,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: style.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: HomeTextStyles.cardTitle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.gradeShort} · ${user.school}',
                    style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final ProfileComment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentText.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(
                comment.authorInitials,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName,
                        style: HomeTextStyles.cardTitle.copyWith(fontSize: 12),
                      ),
                    ),
                    Text(
                      comment.timeAgo,
                      style: HomeTextStyles.bodySmall.copyWith(fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: HomeTextStyles.bodySmall.copyWith(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final ProfileBadge badge;

  @override
  Widget build(BuildContext context) {
    return ProfileBadgeChip(badge: badge);
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.subject});

  final String subject;

  @override
  Widget build(BuildContext context) {
    final color = subjectColor(subject);
    final bg = subjectBackground(subject);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(subjectIcon(subject), size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              subject,
              style: HomeTextStyles.cardTitle.copyWith(fontSize: 13),
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: color),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: HomeTextStyles.statValue.copyWith(fontSize: 18),
          ),
          Text(label, style: HomeTextStyles.bodySmall.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.label,
    required this.value,
    required this.progress,
    required this.accent,
  });

  final String label;
  final String value;
  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: HomeTextStyles.bodySmall),
              Text(
                value,
                style: HomeTextStyles.cardTitle.copyWith(
                  fontSize: 12,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppProgressBar(progress: progress),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.activity,
    required this.onTap,
  });

  final MapActivityItem activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = activity.color;
    return Material(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(activity.icon, size: 18, color: c),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: HomeTextStyles.cardTitle.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.subtitle,
                      style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          activity.timeLabel,
                          style: HomeTextStyles.bodySmall.copyWith(
                            fontSize: 10,
                            color: c,
                          ),
                        ),
                        if (activity.ctaLabel != null) ...[
                          const Spacer(),
                          Text(
                            activity.ctaLabel!,
                            style: HomeTextStyles.badge.copyWith(
                              fontSize: 11,
                              color: c,
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 16, color: c),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodPickerSheet extends StatelessWidget {
  const _MoodPickerSheet({required this.current});

  final StudentMood current;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('How are you studying?', style: HomeTextStyles.cardTitle),
              const SizedBox(height: 4),
              Text(
                'Friends on the map can see your vibe.',
                style: HomeTextStyles.bodySmall,
              ),
              const SizedBox(height: 16),
              ...mapMoodPresets.map((mood) {
                final selected =
                    mood.emoji == current.emoji && mood.label == current.label;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selected
                        ? AppColors.teal.withValues(alpha: 0.12)
                        : AppColors.bgBase,
                    borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, mood),
                      borderRadius:
                          BorderRadius.circular(HomeLayout.cardRadius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(HomeLayout.cardRadius),
                          border: Border.all(
                            color: selected ? AppColors.teal : AppColors.border,
                            width: selected ? 1.2 : 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              mood.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                mood.label,
                                style: HomeTextStyles.cardTitle.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.teal,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
