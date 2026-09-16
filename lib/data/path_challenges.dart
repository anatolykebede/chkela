import 'path_levels.dart';

enum PathChallengeType { strike, blitz, link, sequence, answer }

sealed class PathChallenge {
  const PathChallenge({
    required this.type,
    required this.skillTag,
    required this.waveLabel,
  });

  final PathChallengeType type;
  final String skillTag;
  final String waveLabel;
}

/// Multiple-choice strike (combat framed).
class StrikeChallenge extends PathChallenge {
  const StrikeChallenge({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required super.skillTag,
    super.waveLabel = 'STRIKE',
  }) : super(type: PathChallengeType.strike);

  final String prompt;
  final List<String> options;
  final int correctIndex;
}

/// Timed true / false blitz.
class BlitzChallenge extends PathChallenge {
  const BlitzChallenge({
    required this.prompt,
    required this.isTrue,
    required super.skillTag,
    this.seconds = 8,
    super.waveLabel = 'BLITZ',
  }) : super(type: PathChallengeType.blitz);

  final String prompt;
  final bool isTrue;
  final int seconds;
}

/// Match term ↔ meaning pairs.
class LinkChallenge extends PathChallenge {
  const LinkChallenge({
    required this.pairs,
    required super.skillTag,
    super.waveLabel = 'LINK',
  }) : super(type: PathChallengeType.link);

  /// Left label → right label.
  final Map<String, String> pairs;
}

/// Tap steps in the correct order.
class SequenceChallenge extends PathChallenge {
  const SequenceChallenge({
    required this.title,
    required this.stepsInOrder,
    required super.skillTag,
    super.waveLabel = 'SEQUENCE',
  }) : super(type: PathChallengeType.sequence);

  final String title;
  final List<String> stepsInOrder;
}

/// Short answer / number entry. Works for every subject (Math, Bio, …).
class AnswerChallenge extends PathChallenge {
  const AnswerChallenge({
    required this.prompt,
    required this.correctAnswer,
    required super.skillTag,
    this.acceptedAnswers = const [],
    this.hint,
    this.inputKind = AnswerInputKind.any,
    super.waveLabel = 'ANSWER',
  }) : super(type: PathChallengeType.answer);

  final String prompt;
  final String correctAnswer;
  final List<String> acceptedAnswers;
  final String? hint;
  final AnswerInputKind inputKind;

  bool matches(String raw) {
    final normalized = normalizeAnswer(raw, inputKind);
    if (normalized.isEmpty) return false;
    final targets = [
      correctAnswer,
      ...acceptedAnswers,
    ].map((a) => normalizeAnswer(a, inputKind)).toList();
    if (targets.contains(normalized)) return true;
    // Numeric tolerance: 0.333 ≈ 1/3 after normalize, and float noise.
    final got = num.tryParse(normalized);
    if (got == null) return false;
    for (final t in targets) {
      final want = num.tryParse(t);
      if (want == null) continue;
      final scale = want.abs() < 1 ? 1.0 : want.abs();
      if ((got - want).abs() <= scale * 1e-4 + 1e-9) return true;
    }
    return false;
  }
}

enum AnswerInputKind { any, number, text }

String normalizeAnswer(String raw, AnswerInputKind kind) {
  var s = raw.trim().toLowerCase();
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  // Drop common unit suffixes so "4 cm" matches "4".
  s = s.replaceAll(
    RegExp(
      r'\s*(cm|mm|m|km|kg|g|mg|l|ml|s|sec|seconds|min|°c|celsius|%|degrees?)\s*$',
    ),
    '',
  );
  s = s.replaceAll(RegExp(r'[^\w./+\- ]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (kind == AnswerInputKind.number || kind == AnswerInputKind.any) {
    final frac = RegExp(r'^(-?\d+)\s*/\s*(-?\d+)$').firstMatch(s);
    if (frac != null) {
      final a = num.tryParse(frac.group(1)!);
      final b = num.tryParse(frac.group(2)!);
      if (a != null && b != null && b != 0) {
        return _normalizeNumber(a / b);
      }
    }
    final asNum = num.tryParse(s.replaceAll(',', ''));
    if (asNum != null) return _normalizeNumber(asNum);
  }
  return s;
}

String _normalizeNumber(num value) {
  // Tolerance-friendly canonical form for simple decimals.
  final rounded = (value * 1e6).round() / 1e6;
  if ((rounded - rounded.roundToDouble()).abs() < 1e-9) {
    return rounded.round().toString();
  }
  var out = rounded.toString();
  if (out.contains('.')) {
    out = out.replaceFirst(RegExp(r'0+$'), '');
    out = out.replaceFirst(RegExp(r'\.$'), '');
  }
  return out;
}

StrikeChallenge strikeFromQuestion(PathQuestion q) {
  return StrikeChallenge(
    prompt: q.prompt,
    options: q.options,
    correctIndex: q.correctIndex,
    skillTag: q.skillTag ?? 'practice',
  );
}

/// Builds a short combat run for a gate (mix of mini-games).
List<PathChallenge> challengesForLevel(PathLevel level) {
  final id = level.id;
  final tagged = pathQuestionsByLevelId[id] ?? const <PathQuestion>[];
  final strikes = [for (final q in tagged.take(2)) strikeFromQuestion(q)];

  final specials = _specialsFor(id, level.skillTag);
  final run = <PathChallenge>[
    ...specials,
    ...strikes,
  ];

  if (run.isEmpty) {
    return [
      BlitzChallenge(
        prompt: 'Studying a little every day beats cramming.',
        isTrue: true,
        skillTag: level.skillTag,
      ),
      StrikeChallenge(
        prompt: 'Keep pushing. Which habit wins?',
        options: [
          'Regular practice',
          'Never reviewing',
          'Guessing only',
          'Skipping bosses',
        ],
        correctIndex: 0,
        skillTag: level.skillTag,
      ),
    ];
  }

  // Boss / checkpoint get denser runs.
  if (level.kind == PathLevelKind.boss && tagged.length > 2) {
    run.addAll([for (final q in tagged.skip(2).take(2)) strikeFromQuestion(q)]);
  }
  if (level.kind == PathLevelKind.checkpoint && tagged.length > 2) {
    run.add(strikeFromQuestion(tagged[2]));
  }

  return run;
}

List<PathChallenge> challengesForDaily(List<String> weakSkillTags) {
  final qs = questionsForDaily(weakSkillTags);
  final tag = weakSkillTags.isNotEmpty ? weakSkillTags.first : 'daily';
  if (qs.isNotEmpty) {
    return [
      BlitzChallenge(
        prompt: 'Studying a little every day beats cramming.',
        isTrue: true,
        skillTag: tag,
        seconds: 7,
      ),
      for (final q in qs.take(2)) strikeFromQuestion(q),
    ];
  }
  // Generic fallback when CMS has no waves for this grade yet.
  return [
    BlitzChallenge(
      prompt: 'A streak grows when you practice on consecutive days.',
      isTrue: true,
      skillTag: tag,
      seconds: 7,
    ),
    StrikeChallenge(
      prompt: 'What helps most when a skill keeps tripping you up?',
      options: [
        'Revisit that weak skill',
        'Only play new gates',
        'Skip reviews',
        'Guess forever',
      ],
      correctIndex: 0,
      skillTag: tag,
    ),
    const LinkChallenge(
      skillTag: 'daily',
      pairs: {
        'Practice': 'Builds skill',
        'Streak': 'Daily habit',
        'Review': 'Fixes weak spots',
      },
    ),
  ];
}

List<PathChallenge> _specialsFor(String levelId, String skillTag) {
  switch (levelId) {
    case 'path-1':
      return [
        BlitzChallenge(
          prompt: '“Bios” means life.',
          isTrue: true,
          skillTag: skillTag,
        ),
        const LinkChallenge(
          skillTag: 'define-biology',
          pairs: {
            'Biology': 'Study of living things',
            'Bios': 'Life',
            'Logos': 'Study / knowledge',
          },
        ),
      ];
    case 'path-2':
      return [
        BlitzChallenge(
          prompt: 'Biology has no link to medicine or food.',
          isTrue: false,
          skillTag: skillTag,
        ),
        const LinkChallenge(
          skillTag: 'why-biology',
          pairs: {
            'Vaccines': 'Immune system',
            'Fermentation': 'Microorganisms',
            'Conservation': 'Protect biodiversity',
          },
        ),
      ];
    case 'path-3':
      return [
        const SequenceChallenge(
          title: 'Order the scientific method',
          skillTag: 'scientific-method',
          stepsInOrder: [
            'Observe',
            'Ask a question',
            'Form a hypothesis',
            'Experiment',
            'Conclude',
          ],
        ),
        BlitzChallenge(
          prompt: 'A hypothesis can be impossible to test and still be scientific.',
          isTrue: false,
          skillTag: skillTag,
        ),
      ];
    case 'path-4':
      return [
        const LinkChallenge(
          skillTag: 'lab-tools',
          pairs: {
            'Autoclave': 'Sterilize with steam',
            'Balance': 'Measure mass',
            'Pipette': 'Transfer small liquids',
            'Forceps': 'Pick up specimens',
          },
        ),
        BlitzChallenge(
          prompt: 'A pipette is mainly for weighing rocks.',
          isTrue: false,
          skillTag: skillTag,
        ),
      ];
    case 'path-5':
      return [
        BlitzChallenge(
          prompt: 'Total magnification = eyepiece × objective.',
          isTrue: true,
          skillTag: skillTag,
        ),
        const SequenceChallenge(
          title: 'Use the microscope',
          skillTag: 'microscope',
          stepsInOrder: [
            'Place the slide',
            'Start on low power',
            'Focus the image',
            'Switch to higher power',
          ],
        ),
      ];
    case 'path-6':
      return [
        BlitzChallenge(
          prompt: 'You should never taste lab chemicals.',
          isTrue: true,
          skillTag: skillTag,
          seconds: 6,
        ),
        const LinkChallenge(
          skillTag: 'lab-safety',
          pairs: {
            'Spill': 'Report and clean safely',
            'Broken glass': 'Do not touch barehanded',
            'Unused chemical': 'Dispose properly',
          },
        ),
        const SequenceChallenge(
          title: 'Safe lab start',
          skillTag: 'lab-safety',
          stepsInOrder: [
            'Wear protective gear',
            'Know emergency exits',
            'Read labels',
            'Begin the procedure',
          ],
        ),
      ];
    case 'path-7':
      return [
        BlitzChallenge(
          prompt: 'Reproduction is a trait of living things.',
          isTrue: true,
          skillTag: skillTag,
        ),
        const LinkChallenge(
          skillTag: 'living-traits',
          pairs: {
            'Respiration': 'Energy release',
            'Excretion': 'Remove wastes',
            'Nutrition': 'Obtain food',
            'Sensitivity': 'Respond to stimuli',
          },
        ),
      ];
    case 'path-8':
      return [
        BlitzChallenge(
          prompt: 'Taxonomy is about classifying and naming organisms.',
          isTrue: true,
          skillTag: skillTag,
        ),
        const LinkChallenge(
          skillTag: 'taxonomy',
          pairs: {
            'Taxon': 'A classification group',
            'Taxonomy': 'Naming & grouping life',
            'Shared traits': 'Basis for grouping',
          },
        ),
      ];
    case 'path-9':
      return [
        BlitzChallenge(
          prompt: 'Classification makes studying life more chaotic.',
          isTrue: false,
          skillTag: skillTag,
        ),
        const SequenceChallenge(
          title: 'Why we classify (logic flow)',
          skillTag: 'classification-why',
          stepsInOrder: [
            'Observe diversity',
            'Group by traits',
            'Name groups',
            'Communicate & conserve',
          ],
        ),
      ];
    case 'path-10':
      return [
        BlitzChallenge(
          prompt: 'In Homo sapiens, Homo is the genus.',
          isTrue: true,
          skillTag: skillTag,
        ),
        const LinkChallenge(
          skillTag: 'linnaean',
          pairs: {
            'Genus': 'Homo',
            'Species': 'sapiens',
            'Binomial': 'Two-part name',
          },
        ),
      ];
    case 'path-11':
      return [
        const LinkChallenge(
          skillTag: 'five-kingdoms',
          pairs: {
            'Monera': 'Prokaryotes / bacteria',
            'Plantae': 'Photosynthesize',
            'Animalia': 'Heterotrophs',
            'Fungi': 'Absorb nutrients',
          },
        ),
        BlitzChallenge(
          prompt: 'Fungi are always plants.',
          isTrue: false,
          skillTag: skillTag,
        ),
      ];
    case 'path-12':
      return [
        BlitzChallenge(
          prompt: 'Biology is the scientific study of life.',
          isTrue: true,
          skillTag: skillTag,
          seconds: 5,
        ),
        const SequenceChallenge(
          title: 'Boss sequence: investigation',
          skillTag: 'scientific-method',
          stepsInOrder: [
            'Observe',
            'Hypothesis',
            'Experiment',
            'Conclude',
          ],
        ),
        const LinkChallenge(
          skillTag: 'path-guardian',
          pairs: {
            'Eyepiece × objective': 'Total magnification',
            'Genus + species': 'Binomial name',
            'Never taste': 'Lab safety',
          },
        ),
      ];
    default:
      return [
        BlitzChallenge(
          prompt: 'Practice beats panic before exams.',
          isTrue: true,
          skillTag: skillTag,
        ),
      ];
  }
}

int playerMaxHp(PathLevelKind kind) {
  return switch (kind) {
    PathLevelKind.boss => 4,
    PathLevelKind.checkpoint => 3,
    PathLevelKind.standard => 3,
  };
}

int gateMaxHp(List<PathChallenge> run) => run.length;

/// Stars from combat: hearts left + clear quality.
int starsFromCombat({
  required int playerHpLeft,
  required int playerHpMax,
  required bool gateCleared,
  required PathLevelKind kind,
}) {
  if (!gateCleared || playerHpLeft <= 0) return 0;
  if (playerHpLeft >= playerHpMax) return 3;
  if (playerHpLeft >= playerHpMax - 1) return 2;
  // Boss needs at least 2 hearts conceptually via pass ratio feel
  if (kind == PathLevelKind.boss && playerHpLeft < 2) return 1;
  return 1;
}
