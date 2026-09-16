import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/home_mock_data.dart';
import '../../data/map_profile_store.dart';
import '../../data/map_student_social.dart';

class EditMapProfileScreen extends StatefulWidget {
  const EditMapProfileScreen({super.key});

  @override
  State<EditMapProfileScreen> createState() => _EditMapProfileScreenState();
}

class _EditMapProfileScreenState extends State<EditMapProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _schoolController;
  late final TextEditingController _bioController;
  late final TextEditingController _taglineController;

  late String _grade;
  late String _cityId;
  late StudentMood _mood;
  late Set<String> _subjects;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final store = MapProfileStore.instance;
    final me = store.me;
    _nameController = TextEditingController(
      text: store.displayName?.trim().isNotEmpty == true
          ? store.displayName
          : (me.name == 'Your name' ? '' : me.name),
    );
    _schoolController = TextEditingController(
      text: store.school?.trim().isNotEmpty == true
          ? store.school
          : (me.school == 'Add your school' ? '' : me.school),
    );
    _bioController = TextEditingController(
      text: store.bio?.trim().isNotEmpty == true ? store.bio : '',
    );
    _taglineController = TextEditingController(text: store.tagline ?? '');
    _grade = store.grade ?? me.grade;
    if (!grades.contains(_grade) && !grades.contains(gradeBase(_grade))) {
      _grade = grades.first;
    } else {
      _grade = gradeBase(_grade);
    }
    _cityId = store.cityId ?? mapProfileCities.first.id;
    _mood = store.moodFor(me);
    _subjects = {...store.subjects};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _bioController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one focus subject'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.bgElevated,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    await MapProfileStore.instance.saveMyProfile(
      displayName: _nameController.text,
      school: _schoolController.text,
      bio: _bioController.text,
      grade: _grade,
      subjects: _subjects.toList(),
      cityId: _cityId,
      tagline: _taglineController.text,
      mood: _mood,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved. You are live on the map.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.bgElevated,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Edit map profile',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? 'Saving…' : 'Save',
                      style: HomeTextStyles.badge.copyWith(
                        color: AppColors.teal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Text(
                      'This is what other students see when they tap your pin.',
                      style: HomeTextStyles.bodySmall.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    _FieldLabel('Display name'),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: _inputStyle,
                      decoration: _decoration('e.g. Selam Tadesse'),
                      validator: (v) =>
                          (v == null || v.trim().length < 2)
                              ? 'Enter your name'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel('School'),
                    TextFormField(
                      controller: _schoolController,
                      textCapitalization: TextCapitalization.words,
                      style: _inputStyle,
                      decoration: _decoration('e.g. Bole Secondary School'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Enter your school'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel('Grade'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final grade in grades)
                          _ChoiceChip(
                            label: grade.replaceAll('Grade ', 'Gr '),
                            selected: _grade == grade,
                            onTap: () => setState(() => _grade = grade),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel('City / area (map pin)'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final city in mapProfileCities)
                          _ChoiceChip(
                            label: city.label,
                            selected: _cityId == city.id,
                            onTap: () => setState(() => _cityId = city.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel('Focus subjects (up to 4)'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final subject in mapFocusSubjectOptions)
                          _ChoiceChip(
                            label: subject,
                            selected: _subjects.contains(subject),
                            onTap: () {
                              setState(() {
                                if (_subjects.contains(subject)) {
                                  _subjects.remove(subject);
                                } else if (_subjects.length < 4) {
                                  _subjects.add(subject);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel('Bio'),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      maxLength: 180,
                      style: _inputStyle,
                      decoration: _decoration(
                        'What are you studying? Looking for a study buddy?',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().length < 8)
                              ? 'Write a short bio'
                              : null,
                    ),
                    const SizedBox(height: 8),
                    _FieldLabel('Tagline (optional)'),
                    TextFormField(
                      controller: _taglineController,
                      maxLength: 100,
                      style: _inputStyle,
                      decoration: _decoration(
                        'One line that shows under your highlight',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _FieldLabel('Mood'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final mood in mapMoodPresets)
                          _ChoiceChip(
                            label: '${mood.emoji} ${mood.label}',
                            selected: mood.emoji == _mood.emoji &&
                                mood.label == _mood.label,
                            onTap: () => setState(() => _mood = mood),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(HomeLayout.cardRadius),
                          ),
                        ),
                        child: Text(
                          _saving ? 'Saving…' : 'Save profile',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _inputStyle => GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textPrimary,
      );

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: HomeTextStyles.bodySmall.copyWith(fontSize: 13),
      filled: true,
      fillColor: AppColors.bgElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        borderSide: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        borderSide: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        borderSide: BorderSide(
          color: AppColors.teal.withValues(alpha: 0.7),
          width: 1.2,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: HomeTextStyles.sectionLabel),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.tealSoft : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.teal.withValues(alpha: 0.55)
                : AppColors.border,
            width: selected ? 1.1 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: HomeTextStyles.badge.copyWith(
            color: selected ? AppColors.teal : AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
