import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/map_cities.dart';
import '../../data/map_nearby_students.dart';
import '../../data/map_profile_store.dart';
import '../../data/map_students.dart';
import '../../data/map_tiles.dart';
import 'map_screen_widgets.dart';
import 'map_student_widgets.dart';

class StudentMapProfileScreen extends StatefulWidget {
  const StudentMapProfileScreen({
    super.key,
    required this.student,
  });

  final MapStudent student;

  @override
  State<StudentMapProfileScreen> createState() =>
      _StudentMapProfileScreenState();
}

class _StudentMapProfileScreenState extends State<StudentMapProfileScreen> {
  String? _gradeFilter;
  String? _subjectFilter;

  static const _filterChips = [
    ('all', 'All grades'),
    ('Grade 12', 'Grade 12'),
    ('Mathematics', 'Maths'),
    ('Physics', 'Physics'),
  ];

  MapStudent get student =>
      MapProfileStore.instance.resolveStudent(widget.student);

  List<MapStudent> get _mapMarkers {
    var list = MapProfileStore.instance.students
        .where((s) => !s.isCurrentUser && s.id != student.id);
    if (_gradeFilter != null && _gradeFilter != 'all') {
      list = list.where((s) => s.grade == _gradeFilter);
    }
    if (_subjectFilter != null) {
      list = list.where((s) => s.subjects.contains(_subjectFilter));
    }
    return list.toList();
  }

  void _onFilterTap(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (key == 'all') {
        _gradeFilter = null;
        _subjectFilter = null;
      } else if (key == 'Grade 12') {
        _gradeFilter = 'Grade 12';
        _subjectFilter = null;
      } else {
        _gradeFilter = null;
        _subjectFilter = key;
      }
    });
  }

  bool _isFilterSelected(String key) {
    if (key == 'all') return _gradeFilter == null && _subjectFilter == null;
    if (key == 'Grade 12') return _gradeFilter == 'Grade 12';
    return _subjectFilter == key;
  }

  void _openStudent(MapStudent other) {
    if (other.id == student.id) return;
    context.push('/student/${other.id}/full');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MapProfileStore.instance,
      builder: (context, _) {
        final featured = featuredMapStudentFor(student);
        final nearby = nearbyRowsForStudent(student);
        final onlineDisplay = mapOnlineCount() < 20 ? 24 : mapOnlineCount();
        final profileZoom = student.id == 'yonas-alem' ? 8.5 : 12.5;

        return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: MapScreenHeader(
                title: displayNameForStudent(student),
                onBack: () => context.pop(),
              ),
            ),
            const SliverToBoxAdapter(child: MapSearchRow()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 220,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: student.location,
                        initialZoom: profileZoom,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: mapTileUrlTemplate,
                          userAgentPackageName: mapTileUserAgentPackageName,
                        ),
                        MarkerLayer(
                          markers: [
                            for (final city in ethiopiaCityPins)
                              Marker(
                                point: city.location,
                                width: 56,
                                height: 36,
                                alignment: Alignment.topCenter,
                                child: CityPinMarker(
                                  name: city.name,
                                  color: city.pinColor,
                                ),
                              ),
                            Marker(
                              point: student.location,
                              width: 52,
                              height: 62,
                              alignment: Alignment.topCenter,
                              child: MapStudentMarker(
                                student: student,
                                isSelected: true,
                                onTap: () {},
                              ),
                            ),
                            for (final other in _mapMarkers)
                              Marker(
                                point: other.location,
                                width: 44,
                                height: 50,
                                alignment: Alignment.topCenter,
                                child: MapStudentMarker(
                                  student: other,
                                  isSelected: false,
                                  onTap: () => _openStudent(other),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _filterChips.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        MapFilterChip(
                          label: _filterChips[i].$2,
                          selected: _isFilterSelected(_filterChips[i].$1),
                          onTap: () => _onFilterTap(_filterChips[i].$1),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: FeaturedStudentCard(
                  featured: featured,
                  onMessage: () {
                    final store = MapProfileStore.instance;
                    if (!store.canMessage(student.id)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Add ${student.name.split(' ').first} as a friend to message them.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    context.push('/chat/${Uri.encodeComponent(student.id)}');
                  },
                  onConnect: () => context.push('/student/${student.id}/full'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        context.push('/student/${student.id}/full'),
                    child: Text(
                      'View full profile',
                      style: HomeTextStyles.badge.copyWith(
                        color: AppColors.accentText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(
                  children: [
                    Text('NEARBY STUDENTS', style: HomeTextStyles.sectionLabel),
                    const Spacer(),
                    Text(
                      '$onlineDisplay online now',
                      style: HomeTextStyles.badge.copyWith(
                        color: AppColors.accentText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = nearby[index];
                  return NearbyStudentTile(
                    student: item.student,
                    displayName: item.row.displayName,
                    city: item.row.city,
                    tags: item.row.tags,
                    onConnect: () => _openStudent(item.student),
                  );
                },
                childCount: nearby.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
        );
      },
    );
  }
}
