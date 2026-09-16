import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/home_mock_data.dart';
import '../../data/map_profile_store.dart';
import '../../data/map_students.dart';
import '../../data/map_tiles.dart';
import 'map_student_widgets.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  MapStudent? _selectedStudent;
  String? _gradeFilter;
  double? _regionMinZoom;
  double _mapZoom = mapDefaultZoom;

  static const _regionFitPadding = EdgeInsets.only(
    top: 140,
    left: 20,
    right: 72,
    bottom: 100,
  );

  static const _maxZoom = 18.0;

  LatLngBounds get _regionBounds =>
      LatLngBounds(eastAfricaSouthWest, eastAfricaNorthEast);

  double get _minZoom => _regionMinZoom ?? 3.5;

  double get _markerScale =>
      mapMarkerScaleForZoom(_mapZoom, minZoom: _minZoom);

  List<MapStudent> get _allStudents => MapProfileStore.instance.students;

  List<MapStudent> get _visibleStudents {
    final all = _allStudents;
    if (_gradeFilter == null) return all;
    return all.where((s) => s.grade == _gradeFilter).toList();
  }

  int get _onlineCount => _visibleStudents.where((s) => s.isOnline).length;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _onStudentTap(MapStudent student) async {
    HapticFeedback.selectionClick();
    setState(() => _selectedStudent = student);
    _mapController.move(
      student.location,
      _mapController.camera.zoom,
      offset: const Offset(0, 120),
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MapStudentPreviewSheet(
        student: student,
        onViewProfile: () {
          Navigator.pop(context);
          context.push('/student/${student.id}/full');
        },
      ),
    );

    if (mounted) setState(() => _selectedStudent = null);
  }

  void _recenterMap() {
    HapticFeedback.lightImpact();
    _mapController.move(mapDefaultCenter, mapDefaultZoom);
    setState(() => _selectedStudent = null);
  }

  void _computeRegionMinZoom() {
    if (_regionMinZoom != null) return;
    final fitted = CameraFit.bounds(
      bounds: _regionBounds,
      padding: _regionFitPadding,
    ).fit(_mapController.camera);
    setState(() => _regionMinZoom = fitted.zoom.toDouble());
  }

  void _fitEastAfrica() {
    HapticFeedback.selectionClick();
    _mapController.fitCamera(
      CameraFit.bounds(bounds: _regionBounds, padding: _regionFitPadding),
    );
    setState(() => _selectedStudent = null);
  }

  void _zoomIn() {
    final zoom = (_mapController.camera.zoom + 1)
        .clamp(_minZoom, _maxZoom)
        .toDouble();
    _mapController.move(_mapController.camera.center, zoom);
  }

  void _zoomOut() {
    _computeRegionMinZoom();
    final minZoom = _minZoom;
    if (_mapController.camera.zoom <= minZoom + 0.3) {
      _fitEastAfrica();
      return;
    }
    final zoom = (_mapController.camera.zoom - 1)
        .clamp(minZoom, _maxZoom)
        .toDouble();
    _mapController.move(_mapController.camera.center, zoom);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        body: ListenableBuilder(
          listenable: MapProfileStore.instance,
          builder: (context, _) {
            return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: mapDefaultCenter,
                initialZoom: mapDefaultZoom,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                cameraConstraint: CameraConstraint.contain(
                  bounds: _regionBounds,
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onMapReady: _computeRegionMinZoom,
                onPositionChanged: (camera, _) {
                  if ((camera.zoom - _mapZoom).abs() > 0.01) {
                    setState(() => _mapZoom = camera.zoom);
                  }
                },
                onTap: (_, __) {
                  if (_selectedStudent != null) {
                    setState(() => _selectedStudent = null);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: mapTileUrlTemplate,
                  userAgentPackageName: mapTileUserAgentPackageName,
                ),
                MarkerLayer(
                  markers: [
                    for (final student in _visibleStudents)
                      Marker(
                        point: student.location,
                        width:
                            (mapMarkerBaseWidth * _markerScale).ceilToDouble(),
                        height:
                            (mapMarkerBaseHeight * _markerScale).ceilToDouble(),
                        alignment: Alignment.topCenter,
                        child: MapStudentMarker(
                          student: student,
                          isSelected: _selectedStudent?.id == student.id,
                          onTap: () => _onStudentTap(student),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _MapHeader(
                        studentCount: _visibleStudents.length,
                        onlineCount: _onlineCount,
                        me: MapProfileStore.instance.me,
                        profileComplete:
                            MapProfileStore.instance.isProfileComplete,
                        onOpenProfile: () {
                          HapticFeedback.selectionClick();
                          final store = MapProfileStore.instance;
                          if (!store.isProfileComplete) {
                            context.push('/map/edit-profile');
                          } else {
                            context.push('/student/${store.me.id}/full');
                          }
                        },
                        onEditProfile: () {
                          HapticFeedback.selectionClick();
                          context.push('/map/edit-profile');
                        },
                        onOpenChats: () {
                          HapticFeedback.selectionClick();
                          context.push('/chats');
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _GradeFilterChip(
                            label: 'All grades',
                            selected: _gradeFilter == null,
                            onTap: () => setState(() => _gradeFilter = null),
                          ),
                          for (final grade in grades) ...[
                            const SizedBox(width: 8),
                            _GradeFilterChip(
                              label: grade.replaceAll('Grade ', 'Gr '),
                              selected: _gradeFilter == grade,
                              onTap: () =>
                                  setState(() => _gradeFilter = grade),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    _MapControlButton(
                      icon: Icons.my_location,
                      onTap: _recenterMap,
                    ),
                    const SizedBox(height: 10),
                    _MapControlButton(icon: Icons.add, onTap: _zoomIn),
                    const SizedBox(height: 8),
                    _MapControlButton(icon: Icons.remove, onTap: _zoomOut),
                  ],
                ),
              ),
            ),
          ],
            );
          },
        ),
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.studentCount,
    required this.onlineCount,
    required this.me,
    required this.profileComplete,
    required this.onOpenProfile,
    required this.onEditProfile,
    required this.onOpenChats,
  });

  final int studentCount;
  final int onlineCount;
  final MapStudent me;
  final bool profileComplete;
  final VoidCallback onOpenProfile;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenChats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgOverlay.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.accentText,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Students near you',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profileComplete
                          ? '$studentCount nearby · $onlineCount online'
                          : 'Complete your profile to stand out on the map',
                      style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onOpenChats,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onOpenProfile,
                onLongPress: onEditProfile,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.tealSoft,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: profileComplete
                              ? AppColors.teal
                              : AppColors.amber,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          me.initials,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: profileComplete
                              ? AppColors.teal
                              : AppColors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.bgOverlay,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          profileComplete
                              ? Icons.person
                              : Icons.edit,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!profileComplete) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onEditProfile,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.amberSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Add name, school, bio, subjects & pin location',
                        style: HomeTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      'Edit',
                      style: HomeTextStyles.badge.copyWith(
                        color: AppColors.amber,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GradeFilterChip extends StatelessWidget {
  const _GradeFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentSoft
              : AppColors.bgOverlay.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.accentText.withValues(alpha: 0.4)
                : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: HomeTextStyles.badge.copyWith(
            color: selected ? AppColors.accentText : AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.bgOverlay.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 22),
      ),
    );
  }
}
