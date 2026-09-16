import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

enum PathLevelKind { standard, checkpoint, boss }

enum PathLevelStatus { locked, current, cleared }

/// Synthetic id for the daily streak challenge (not on the map trail).
const kPathDailyId = 'path-daily';

class PathLevel {
  const PathLevel({
    required this.id,
    required this.number,
    required this.title,
    required this.kind,
    required this.subject,
    required this.xpReward,
    required this.competency,
    required this.skillTag,
    required this.hook,
    this.lessonId,
    this.arenaLabel,
    this.status = 'published',
    this.gradeId = 'grade-9',
  });

  final String id;
  final int number;
  final String title;
  final PathLevelKind kind;
  final String subject;
  final int xpReward;

  /// MoE learning competency this gate proves.
  final String competency;

  /// Used for weak-skill tracking and daily challenges.
  final String skillTag;

  /// 30s coach tip shown before questions.
  final String hook;

  final String? lessonId;
  final String? arenaLabel;
  final String status;

  /// CMS grade id: `grade-9` … `grade-12`.
  final String gradeId;

  factory PathLevel.fromJson(Map<String, dynamic> json) {
    final kindRaw = json['kind']?.toString() ?? 'standard';
    final kind = switch (kindRaw) {
      'boss' => PathLevelKind.boss,
      'checkpoint' => PathLevelKind.checkpoint,
      _ => PathLevelKind.standard,
    };
    return PathLevel(
      id: json['id']?.toString() ?? '',
      number: (json['number'] as num?)?.toInt() ?? 1,
      title: json['title']?.toString() ?? 'Gate',
      kind: kind,
      subject: json['subject']?.toString() ?? 'Biology',
      xpReward: (json['xpReward'] as num?)?.toInt() ?? 25,
      competency: json['competency']?.toString() ?? '',
      skillTag: json['skillTag']?.toString() ?? 'practice',
      hook: json['hook']?.toString() ?? '',
      lessonId: json['lessonId']?.toString(),
      arenaLabel: json['arenaLabel']?.toString(),
      status: json['status']?.toString() ?? 'published',
      gradeId: json['gradeId']?.toString() ?? 'grade-9',
    );
  }
}

/// Maps home grade selection → Path `gradeId`.
String pathGradeIdFromSelection(String selection) {
  final lower = selection.toLowerCase();
  if (lower.contains('12')) return 'grade-12';
  if (lower.contains('11')) return 'grade-11';
  if (lower.contains('10')) return 'grade-10';
  return 'grade-9';
}

/// Grades 9–11: own grade only. Grade 12: all of 9–12.
Set<String> pathVisibleGradeIds(String selection) {
  final id = pathGradeIdFromSelection(selection);
  if (id == 'grade-12') {
    return const {'grade-9', 'grade-10', 'grade-11', 'grade-12'};
  }
  return {id};
}

int pathGradeSortKey(String gradeId) {
  return switch (gradeId) {
    'grade-10' => 10,
    'grade-11' => 11,
    'grade-12' => 12,
    _ => 9,
  };
}

/// Grade 9 Biology Path seed (fallback if CMS catalog is unavailable).
const pathLevels = <PathLevel>[
  PathLevel(
    id: 'path-1',
    number: 1,
    title: 'Define Biology',
    kind: PathLevelKind.standard,
    subject: 'Biology',
    xpReward: 25,
    lessonId: 'bio9-ch1-l1',
    competency: 'Define biology',
    skillTag: 'define-biology',
    hook: 'Biology is the scientific study of life. Bios = life, logos = study.',
    arenaLabel: 'ARENA I · UNIT 1',
  ),
  PathLevel(
    id: 'path-2',
    number: 2,
    title: 'Why Biology?',
    kind: PathLevelKind.standard,
    subject: 'Biology',
    xpReward: 25,
    lessonId: 'bio9-ch1-l2',
    competency: 'Explain why biology is studied',
    skillTag: 'why-biology',
    hook: 'Biology powers health, food, environment, and careers. Know the why.',
  ),
  PathLevel(
    id: 'path-3',
    number: 3,
    title: 'Scientific Method',
    kind: PathLevelKind.checkpoint,
    subject: 'Biology',
    xpReward: 45,
    lessonId: 'bio9-ch1-l3',
    competency: 'Plan a biological investigation using the scientific method',
    skillTag: 'scientific-method',
    hook: 'Checkpoint: mix define + why + method. Observation → hypothesis → test.',
  ),
  PathLevel(
    id: 'path-4',
    number: 4,
    title: 'Lab Tools',
    kind: PathLevelKind.standard,
    subject: 'Biology',
    xpReward: 30,
    lessonId: 'bio9-ch1-l4',
    competency: 'Identify some common tools of a biologist',
    skillTag: 'lab-tools',
    hook: 'Match tool to job: autoclave sterilizes, balance weighs, pipette measures.',
  ),
  PathLevel(
    id: 'path-5',
    number: 5,
    title: 'Microscope',
    kind: PathLevelKind.standard,
    subject: 'Biology',
    xpReward: 30,
    lessonId: 'bio9-ch1-l5',
    competency: 'Utilize a microscope',
    skillTag: 'microscope',
    hook: 'Total magnification = eyepiece × objective. Start on low power.',
  ),
  PathLevel(
    id: 'path-6',
    number: 6,
    title: 'Lab Safety Boss',
    kind: PathLevelKind.boss,
    subject: 'Biology',
    xpReward: 90,
    lessonId: 'bio9-ch1-l6',
    competency: 'Execute general laboratory safety rules',
    skillTag: 'lab-safety',
    hook: 'Boss gate: Unit 1 exam feel. Safety first, then prove all six competencies.',
  ),
  PathLevel(
    id: 'path-7',
    number: 7,
    title: 'Living Things',
    kind: PathLevelKind.standard,
    subject: 'Biology',
    xpReward: 30,
    lessonId: 'bio9-ch2-l1',
    competency: 'State the characteristics of living things',
    skillTag: 'living-traits',
    hook: 'MRS GREN: movement, respiration, sensitivity, growth, reproduction, excretion, nutrition.',
    arenaLabel: 'ARENA II · UNIT 2',
  ),
  PathLevel(
    id: 'path-8',
    number: 8,
    title: 'Taxonomy',
    kind: PathLevelKind.standard,
    subject: 'Biology',
    xpReward: 35,
    lessonId: 'bio9-ch2-l2',
    competency: 'Classify living things based on taxonomic principles',
    skillTag: 'taxonomy',
    hook: 'Taxonomy groups organisms by shared features so we can name and study them.',
  ),
  PathLevel(
    id: 'path-9',
    number: 9,
    title: 'Why Classify?',
    kind: PathLevelKind.checkpoint,
    subject: 'Biology',
    xpReward: 55,
    lessonId: 'bio9-ch2-l3',
    competency: 'Argue for or against the importance of classification',
    skillTag: 'classification-why',
    hook: 'Checkpoint: living traits + taxonomy + why classification matters.',
  ),
  PathLevel(
    id: 'path-10',
    number: 10,
    title: 'Linnaean Names',
    kind: PathLevelKind.standard,
    subject: 'Biology',
    xpReward: 35,
    lessonId: 'bio9-ch2-l4',
    competency: 'Describe the system of Linnaean nomenclature',
    skillTag: 'linnaean',
    hook: 'Binomial: Genus species. Homo sapiens. Genus capital, species lower case.',
  ),
  PathLevel(
    id: 'path-11',
    number: 11,
    title: 'Five Kingdoms',
    kind: PathLevelKind.standard,
    subject: 'Biology',
    xpReward: 40,
    lessonId: 'bio9-ch2-l6',
    competency: 'List the characteristic features of the five kingdoms',
    skillTag: 'five-kingdoms',
    hook: 'Monera, Protista, Fungi, Plantae, Animalia. Know one standout feature each.',
  ),
  PathLevel(
    id: 'path-12',
    number: 12,
    title: 'Path Guardian',
    kind: PathLevelKind.boss,
    subject: 'Biology',
    xpReward: 120,
    competency: 'Prove Unit 1 and early Unit 2 under exam pressure',
    skillTag: 'path-guardian',
    hook: 'Final boss: mixed Unit 1 + Unit 2. Chase 3 stars. Own the arena.',
  ),
];

PathLevel? pathLevelById(String id) {
  if (id == kPathDailyId) return pathDailyLevel;
  for (final level in pathLevels) {
    if (level.id == id) return level;
  }
  return null;
}

const pathDailyLevel = PathLevel(
  id: kPathDailyId,
  number: 0,
  title: 'Daily Streak Gate',
  kind: PathLevelKind.checkpoint,
  subject: 'General',
  xpReward: 40,
  competency: 'Revisit yesterday weak skills',
  skillTag: 'daily',
  hook: 'One short gate a day keeps your streak alive. Weak skills come back.',
);

class PathQuestion {
  const PathQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.skillTag,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? skillTag;
}

/// Stars: 3 = perfect, 2 = ≥80%, 1 = pass, 0 = fail.
int starsFromScore({
  required int correct,
  required int total,
  required PathLevelKind kind,
}) {
  if (total <= 0) return 0;
  final ratio = correct / total;
  final pass = switch (kind) {
    PathLevelKind.boss => 0.7,
    PathLevelKind.checkpoint => 0.6,
    PathLevelKind.standard => 0.5,
  };
  if (ratio < pass) return 0;
  if (ratio >= 0.999) return 3;
  if (ratio >= 0.8) return 2;
  return 1;
}

int xpForStars(PathLevel level, int stars) {
  if (stars <= 0) return 0;
  return ((level.xpReward * stars) / 3).round();
}

const pathQuestionsByLevelId = <String, List<PathQuestion>>{
  'path-1': [
    PathQuestion(
      prompt: 'Biology is best defined as the scientific study of:',
      options: ['Rocks and minerals', 'Life / living things', 'Stars only', 'Machines'],
      correctIndex: 1,
      skillTag: 'define-biology',
    ),
    PathQuestion(
      prompt: 'The Greek root “bios” means:',
      options: ['Water', 'Life', 'Earth', 'Energy'],
      correctIndex: 1,
      skillTag: 'define-biology',
    ),
    PathQuestion(
      prompt: 'A biologist studies:',
      options: [
        'Only non-living matter',
        'Living organisms and life processes',
        'Only weather maps',
        'Only computer code',
      ],
      correctIndex: 1,
      skillTag: 'define-biology',
    ),
    PathQuestion(
      prompt: 'Which statement is true?',
      options: [
        'Biology ignores living systems',
        'Biology includes plants, animals, and microbes',
        'Biology is only about rocks',
        'Biology never uses experiments',
      ],
      correctIndex: 1,
      skillTag: 'define-biology',
    ),
  ],
  'path-2': [
    PathQuestion(
      prompt: 'A real-world use of biology is:',
      options: [
        'Writing poetry only',
        'Developing medicines',
        'Building bridges',
        'Painting walls',
      ],
      correctIndex: 1,
      skillTag: 'why-biology',
    ),
    PathQuestion(
      prompt: 'Fermentation in food production depends on:',
      options: ['Microorganisms', 'Magnets', 'Solar panels', 'Concrete'],
      correctIndex: 0,
      skillTag: 'why-biology',
    ),
    PathQuestion(
      prompt: 'Studying biology helps us:',
      options: [
        'Ignore disease',
        'Understand health and the environment',
        'Avoid all farming',
        'Stop reading',
      ],
      correctIndex: 1,
      skillTag: 'why-biology',
    ),
    PathQuestion(
      prompt: 'Vaccines relate to biology because they:',
      options: [
        'Are only about metals',
        'Work with the immune system',
        'Replace gravity',
        'Measure earthquakes',
      ],
      correctIndex: 1,
      skillTag: 'why-biology',
    ),
  ],
  'path-3': [
    PathQuestion(
      prompt: 'A hypothesis must be:',
      options: ['Impossible to test', 'A proven law', 'Testable', 'A random guess only'],
      correctIndex: 2,
      skillTag: 'scientific-method',
    ),
    PathQuestion(
      prompt: 'A common first step of the scientific method is:',
      options: ['Publishing', 'Observation', 'Ignoring data', 'Skipping experiments'],
      correctIndex: 1,
      skillTag: 'scientific-method',
    ),
    PathQuestion(
      prompt: 'Biology is the study of:',
      options: ['Life', 'Only volcanoes', 'Only engines', 'Only weather'],
      correctIndex: 0,
      skillTag: 'define-biology',
    ),
    PathQuestion(
      prompt: 'After collecting data, a scientist should:',
      options: [
        'Throw it away',
        'Analyze and draw a conclusion',
        'Never compare to the hypothesis',
        'Hide unexpected results',
      ],
      correctIndex: 1,
      skillTag: 'scientific-method',
    ),
    PathQuestion(
      prompt: 'Why study biology?',
      options: [
        'It has no practical use',
        'It informs medicine, food, and conservation',
        'Only for memorizing names',
        'To avoid nature',
      ],
      correctIndex: 1,
      skillTag: 'why-biology',
    ),
  ],
  'path-4': [
    PathQuestion(
      prompt: 'An autoclave is mainly used to:',
      options: [
        'Weigh samples',
        'Sterilize with steam',
        'Catch insects',
        'Measure pH only',
      ],
      correctIndex: 1,
      skillTag: 'lab-tools',
    ),
    PathQuestion(
      prompt: 'A balance (scale) in the lab is used to:',
      options: ['Measure mass', 'Heat liquids', 'Sterilize tools', 'Cut tissue'],
      correctIndex: 0,
      skillTag: 'lab-tools',
    ),
    PathQuestion(
      prompt: 'A pipette is best for:',
      options: [
        'Transferring small liquid volumes',
        'Crushing rocks',
        'Catching butterflies',
        'Measuring room temperature only',
      ],
      correctIndex: 0,
      skillTag: 'lab-tools',
    ),
    PathQuestion(
      prompt: 'Forceps are used to:',
      options: [
        'Hold or pick up small specimens',
        'Boil water',
        'Grow bacteria overnight',
        'Replace a microscope',
      ],
      correctIndex: 0,
      skillTag: 'lab-tools',
    ),
  ],
  'path-5': [
    PathQuestion(
      prompt: 'Total magnification equals:',
      options: [
        'Eyepiece − objective',
        'Eyepiece × objective',
        'Eyepiece + objective',
        'Objective only',
      ],
      correctIndex: 1,
      skillTag: 'microscope',
    ),
    PathQuestion(
      prompt: 'You should start observing a slide on:',
      options: [
        'Highest power first',
        'Lowest power first',
        'Oil immersion only',
        'No lens at all',
      ],
      correctIndex: 1,
      skillTag: 'microscope',
    ),
    PathQuestion(
      prompt: 'The eyepiece is also called the:',
      options: ['Objective', 'Ocular lens', 'Stage clip', 'Diaphragm only'],
      correctIndex: 1,
      skillTag: 'microscope',
    ),
    PathQuestion(
      prompt: 'The stage of a microscope:',
      options: [
        'Holds the slide',
        'Is the light switch only',
        'Is the carrying handle only',
        'Replaces the objective',
      ],
      correctIndex: 0,
      skillTag: 'microscope',
    ),
  ],
  'path-6': [
    PathQuestion(
      prompt: 'In the lab you should never:',
      options: [
        'Wear closed shoes',
        'Taste chemicals',
        'Label containers',
        'Know where the first-aid kit is',
      ],
      correctIndex: 1,
      skillTag: 'lab-safety',
    ),
    PathQuestion(
      prompt: 'Unused chemicals should:',
      options: [
        'Be poured back into stock bottles',
        'Be disposed of properly (not returned to stock)',
        'Be tasted carefully',
        'Be left unlabeled',
      ],
      correctIndex: 1,
      skillTag: 'lab-safety',
    ),
    PathQuestion(
      prompt: 'If glassware breaks, you should:',
      options: [
        'Ignore it',
        'Report it and clean up safely',
        'Hide the pieces',
        'Walk barefoot over it',
      ],
      correctIndex: 1,
      skillTag: 'lab-safety',
    ),
    PathQuestion(
      prompt: 'Biology is the scientific study of:',
      options: ['Life', 'Only stars', 'Only machines', 'Only maps'],
      correctIndex: 0,
      skillTag: 'define-biology',
    ),
    PathQuestion(
      prompt: 'Total magnification is:',
      options: [
        'Eyepiece × objective',
        'Eyepiece + objective',
        'Objective alone',
        'Eyepiece alone',
      ],
      correctIndex: 0,
      skillTag: 'microscope',
    ),
    PathQuestion(
      prompt: 'A testable prediction in science is a:',
      options: ['Hypothesis', 'Random myth', 'Unrelated joke', 'Locked door'],
      correctIndex: 0,
      skillTag: 'scientific-method',
    ),
  ],
  'path-7': [
    PathQuestion(
      prompt: 'Which is a characteristic of living things?',
      options: ['Respiration', 'Being made of plastic', 'Never changing', 'Having no cells'],
      correctIndex: 0,
      skillTag: 'living-traits',
    ),
    PathQuestion(
      prompt: 'Growth in living organisms means:',
      options: [
        'Irreversible increase in size/complexity',
        'Only changing color once',
        'Turning into metal',
        'Stopping all metabolism',
      ],
      correctIndex: 0,
      skillTag: 'living-traits',
    ),
    PathQuestion(
      prompt: 'Excretion is the removal of:',
      options: [
        'Metabolic waste',
        'Useful food only',
        'Sunlight',
        'Soil minerals only',
      ],
      correctIndex: 0,
      skillTag: 'living-traits',
    ),
    PathQuestion(
      prompt: 'Reproduction allows living things to:',
      options: [
        'Produce offspring',
        'Stop needing energy',
        'Become non-living',
        'Avoid all change',
      ],
      correctIndex: 0,
      skillTag: 'living-traits',
    ),
  ],
  'path-8': [
    PathQuestion(
      prompt: 'Taxonomy is mainly about:',
      options: [
        'Classifying and naming organisms',
        'Cooking recipes',
        'Building roads',
        'Measuring only temperature',
      ],
      correctIndex: 0,
      skillTag: 'taxonomy',
    ),
    PathQuestion(
      prompt: 'Organisms are grouped using:',
      options: [
        'Shared characteristics',
        'Random letter codes only',
        'Shoe size only',
        'Favorite colors',
      ],
      correctIndex: 0,
      skillTag: 'taxonomy',
    ),
    PathQuestion(
      prompt: 'A taxon is:',
      options: [
        'A classification group',
        'A lab burner',
        'A type of pipette',
        'A weather cloud',
      ],
      correctIndex: 0,
      skillTag: 'taxonomy',
    ),
    PathQuestion(
      prompt: 'Classification helps scientists:',
      options: [
        'Organize biodiversity and communicate clearly',
        'Ignore species differences',
        'Avoid naming organisms',
        'Study only one rock',
      ],
      correctIndex: 0,
      skillTag: 'taxonomy',
    ),
  ],
  'path-9': [
    PathQuestion(
      prompt: 'Classification is important because it:',
      options: [
        'Helps identify and study organisms systematically',
        'Makes biology less useful',
        'Removes all Latin names',
        'Stops research',
      ],
      correctIndex: 0,
      skillTag: 'classification-why',
    ),
    PathQuestion(
      prompt: 'Without classification, studying life would be:',
      options: [
        'More chaotic and harder to communicate',
        'Exactly the same',
        'Unnecessary',
        'Only about machines',
      ],
      correctIndex: 0,
      skillTag: 'classification-why',
    ),
    PathQuestion(
      prompt: 'Living things typically show:',
      options: [
        'Nutrition and respiration',
        'No need for energy',
        'Zero response to stimuli',
        'No growth ever',
      ],
      correctIndex: 0,
      skillTag: 'living-traits',
    ),
    PathQuestion(
      prompt: 'Taxonomy groups organisms by:',
      options: [
        'Shared features',
        'Random chance only',
        'Phone numbers',
        'Map coordinates only',
      ],
      correctIndex: 0,
      skillTag: 'taxonomy',
    ),
    PathQuestion(
      prompt: 'Arguing for classification often includes that it:',
      options: [
        'Supports conservation and medicine',
        'Has no link to real problems',
        'Only confuses students',
        'Replaces all experiments',
      ],
      correctIndex: 0,
      skillTag: 'classification-why',
    ),
  ],
  'path-10': [
    PathQuestion(
      prompt: 'Linnaean binomial names have:',
      options: [
        'Genus and species',
        'Only a nickname',
        'Only a kingdom',
        'A random number',
      ],
      correctIndex: 0,
      skillTag: 'linnaean',
    ),
    PathQuestion(
      prompt: 'In Homo sapiens, Homo is the:',
      options: ['Genus', 'Species', 'Family only', 'Phylum only'],
      correctIndex: 0,
      skillTag: 'linnaean',
    ),
    PathQuestion(
      prompt: 'The species name is usually written:',
      options: [
        'In lowercase',
        'In ALL CAPS always',
        'As numbers only',
        'Without Latin roots',
      ],
      correctIndex: 0,
      skillTag: 'linnaean',
    ),
    PathQuestion(
      prompt: 'Scientific names are useful because they:',
      options: [
        'Are unique and shared worldwide',
        'Change every hour',
        'Only work in one village',
        'Replace all local languages',
      ],
      correctIndex: 0,
      skillTag: 'linnaean',
    ),
  ],
  'path-11': [
    PathQuestion(
      prompt: 'Which is one of the five kingdoms?',
      options: ['Fungi', 'Vehicles', 'Planets', 'Languages'],
      correctIndex: 0,
      skillTag: 'five-kingdoms',
    ),
    PathQuestion(
      prompt: 'Plantae organisms typically:',
      options: [
        'Photosynthesize',
        'Never have cells',
        'Are always bacterial only',
        'Lack chlorophyll by definition',
      ],
      correctIndex: 0,
      skillTag: 'five-kingdoms',
    ),
    PathQuestion(
      prompt: 'Animalia organisms are generally:',
      options: [
        'Heterotrophic and multicellular',
        'Always photosynthetic',
        'Non-living crystals',
        'Only unicellular bacteria',
      ],
      correctIndex: 0,
      skillTag: 'five-kingdoms',
    ),
    PathQuestion(
      prompt: 'Monera mainly includes:',
      options: [
        'Prokaryotes such as bacteria',
        'Only flowering plants',
        'Only mammals',
        'Only mushrooms',
      ],
      correctIndex: 0,
      skillTag: 'five-kingdoms',
    ),
  ],
  'path-12': [
    PathQuestion(
      prompt: 'Biology is the study of:',
      options: ['Life', 'Only geology', 'Only astronomy', 'Only coding'],
      correctIndex: 0,
      skillTag: 'define-biology',
    ),
    PathQuestion(
      prompt: 'A hypothesis should be:',
      options: ['Testable', 'Impossible', 'Secret forever', 'Unrelated to data'],
      correctIndex: 0,
      skillTag: 'scientific-method',
    ),
    PathQuestion(
      prompt: 'Never do this in the lab:',
      options: [
        'Taste chemicals',
        'Wear protective gear',
        'Label samples',
        'Wash hands',
      ],
      correctIndex: 0,
      skillTag: 'lab-safety',
    ),
    PathQuestion(
      prompt: 'Total magnification is:',
      options: [
        'Eyepiece × objective',
        'Eyepiece − objective',
        'Objective ÷ eyepiece',
        'Stage × mirror',
      ],
      correctIndex: 0,
      skillTag: 'microscope',
    ),
    PathQuestion(
      prompt: 'Living things show:',
      options: [
        'Growth and reproduction',
        'No metabolism',
        'Zero response to the environment',
        'No need for nutrition',
      ],
      correctIndex: 0,
      skillTag: 'living-traits',
    ),
    PathQuestion(
      prompt: 'Binomial nomenclature uses:',
      options: [
        'Genus + species',
        'Only kingdom',
        'Only phylum',
        'A barcode only',
      ],
      correctIndex: 0,
      skillTag: 'linnaean',
    ),
    PathQuestion(
      prompt: 'Fungi belong to:',
      options: [
        'Their own kingdom among the five',
        'Only Plantae always',
        'Only Animalia always',
        'Non-living matter',
      ],
      correctIndex: 0,
      skillTag: 'five-kingdoms',
    ),
    PathQuestion(
      prompt: 'Classification helps because it:',
      options: [
        'Organizes life for study and communication',
        'Removes all names',
        'Stops taxonomy',
        'Ignores shared traits',
      ],
      correctIndex: 0,
      skillTag: 'classification-why',
    ),
  ],
};

List<PathQuestion> questionsForLevel(String levelId) {
  return pathQuestionsByLevelId[levelId] ??
      const [
        PathQuestion(
          prompt: 'Keep practicing. Which habit helps most?',
          options: [
            'Studying regularly beats cramming',
            'Skipping reviews is best',
            'Guessing is always enough',
            'Notes are useless',
          ],
          correctIndex: 0,
          skillTag: 'daily',
        ),
      ];
}

/// Daily gate: prefer weak skills, else a rotating Unit 1 mix.
List<PathQuestion> questionsForDaily(List<String> weakSkillTags) {
  final pool = <PathQuestion>[];
  for (final entry in pathQuestionsByLevelId.entries) {
    if (entry.key == 'path-12') continue;
    pool.addAll(entry.value);
  }

  final weak = weakSkillTags.toSet();
  final preferred = pool
      .where((q) => q.skillTag != null && weak.contains(q.skillTag))
      .toList();
  final source = preferred.isNotEmpty ? preferred : pool;
  final daySeed = DateTime.now().year * 1000 + DateTime.now().month * 40 + DateTime.now().day;
  final picked = <PathQuestion>[];
  for (var i = 0; i < 4 && source.isNotEmpty; i++) {
    picked.add(source[(daySeed + i * 7) % source.length]);
  }
  return picked.isEmpty ? questionsForLevel('path-1') : picked;
}

Color pathKindColor(PathLevelKind kind) {
  switch (kind) {
    case PathLevelKind.standard:
      return AppColors.accent;
    case PathLevelKind.checkpoint:
      return AppColors.teal;
    case PathLevelKind.boss:
      return AppColors.amber;
  }
}

IconData pathKindIcon(PathLevelKind kind) {
  switch (kind) {
    case PathLevelKind.standard:
      return Icons.circle;
    case PathLevelKind.checkpoint:
      return Icons.flag_rounded;
    case PathLevelKind.boss:
      return Icons.local_fire_department_rounded;
  }
}
