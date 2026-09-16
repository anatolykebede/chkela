class NoteSessionArgs {
  const NoteSessionArgs({
    required this.subjectName,
    required this.chapterTitle,
    required this.chapterId,
    required this.noteId,
    required this.noteTitle,
  });

  final String subjectName;
  final String chapterTitle;
  final String chapterId;
  final String noteId;
  final String noteTitle;
}

class NoteAsset {
  const NoteAsset({
    required this.assetPath,
    this.sectionAnchor,
  });

  final String assetPath;
  final String? sectionAnchor;
}

const _biologyCh1Asset = 'assets/notes/biology_ch1.html';

/// Maps note IDs to bundled HTML assets and optional in-page section anchors.
const noteAssetsById = <String, NoteAsset>{
  'biology-ch1-note-1': NoteAsset(
    assetPath: _biologyCh1Asset,
    sectionAnchor: 's1',
  ),
  'biology-ch1-note-2': NoteAsset(
    assetPath: _biologyCh1Asset,
    sectionAnchor: 's2',
  ),
  'biology-ch1-note-3': NoteAsset(
    assetPath: _biologyCh1Asset,
    sectionAnchor: 's1',
  ),
  'biology-ch1-note-4': NoteAsset(
    assetPath: _biologyCh1Asset,
    sectionAnchor: 's1',
  ),
  'biology-ch1-note-5': NoteAsset(
    assetPath: _biologyCh1Asset,
    sectionAnchor: 's3',
  ),
  'biology-ch1-note-6': NoteAsset(
    assetPath: _biologyCh1Asset,
    sectionAnchor: 's1',
  ),
};

NoteAsset? noteAssetFor(String noteId) => noteAssetsById[noteId];
