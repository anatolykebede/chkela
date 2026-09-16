import { useCallback, useEffect, useMemo, useState, type FormEvent, type ReactNode } from 'react'
import {
  BookOpen,
  ChevronRight,
  ClipboardList,
  FileText,
  GraduationCap,
  Layers,
  Plus,
  Trash2,
  Video,
  StickyNote,
} from 'lucide-react'
import { PageHeader } from '../components/PageHeader'
import { Badge } from '../components/Badge'
import { QuestionBankEditor, newQuestion } from '../components/QuestionBankEditor'
import { RichContentFields } from '../components/RichContentFields'
import '../components/RichContentFields.css'
import {
  deleteContentItem,
  durationFromQuestionCount,
  fetchCatalog,
  MINUTES_PER_QUESTION,
  upsertContentItem,
  type ContentCatalog,
  type ContentChapter,
  type ContentQuestion,
  type ContentSubjectExam,
  type PublishStatus,
  type SubjectExamType,
} from '../lib/contentApi'
import '../components/DataTable.css'
import './Pages.css'
import './ContentPage.css'

type SubjectTab = 'chapters' | 'mid' | 'final' | 'matric'
type ChapterTab = 'lessons' | 'notes' | 'flashcards' | 'quizzes' | 'chapterExams'

type MatricSourceRow = {
  key: string
  gradeId: string
  subjectId: string
  chapterId: string
  questionCount: string
}

const emptyCatalog: ContentCatalog = {
  grades: [],
  subjects: [],
  chapters: [],
  lessons: [],
  notes: [],
  quizzes: [],
  chapterExams: [],
  exams: [],
  flashcardDecks: [],
  flashcards: [],
}

export function ContentPage() {
  const [catalog, setCatalog] = useState<ContentCatalog>(emptyCatalog)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [gradeId, setGradeId] = useState('')
  const [subjectId, setSubjectId] = useState<string | null>(null)
  const [chapterId, setChapterId] = useState<string | null>(null)
  const [subjectTab, setSubjectTab] = useState<SubjectTab>('chapters')
  const [chapterTab, setChapterTab] = useState<ChapterTab>('lessons')
  const [editorOpen, setEditorOpen] = useState(false)
  const [editorMode, setEditorMode] = useState<
    | 'grade'
    | 'subject'
    | 'chapter'
    | 'lesson'
    | 'note'
    | 'quiz'
    | 'chapterExam'
    | 'subjectExam'
    | 'flashcardDeck'
    | 'flashcard'
    | null
  >(null)
  const [draft, setDraft] = useState<Record<string, string>>({})
  /** Cross-grade matric question origins (grade + chapter + count). */
  const [matricSourceRows, setMatricSourceRows] = useState<MatricSourceRow[]>([])
  /** MCQ bank for quiz / chapter exam editors. */
  const [draftQuestions, setDraftQuestions] = useState<ContentQuestion[]>([])
  const [saving, setSaving] = useState(false)
  const [flashDeckId, setFlashDeckId] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    setError('')
    try {
      const next = await fetchCatalog()
      setCatalog(next)
      setGradeId((current) => current || next.grades[0]?.id || '')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load content')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const subjects = useMemo(
    () => catalog.subjects.filter((s) => s.gradeId === gradeId),
    [catalog.subjects, gradeId],
  )

  const subject = useMemo(
    () => catalog.subjects.find((s) => s.id === subjectId) ?? null,
    [catalog.subjects, subjectId],
  )

  const chapters = useMemo(
    () =>
      catalog.chapters
        .filter((c) => c.subjectId === subjectId)
        .sort((a, b) => a.order - b.order),
    [catalog.chapters, subjectId],
  )

  const chapter = useMemo(
    () => catalog.chapters.find((c) => c.id === chapterId) ?? null,
    [catalog.chapters, chapterId],
  )

  const gradeLabel =
    catalog.grades.find((g) => g.id === gradeId)?.label ?? 'Grade'

  function selectGrade(id: string) {
    setGradeId(id)
    setSubjectId(null)
    setChapterId(null)
    setFlashDeckId(null)
    setSubjectTab('chapters')
  }

  function selectSubject(id: string) {
    setSubjectId(id)
    setChapterId(null)
    setFlashDeckId(null)
    setSubjectTab('chapters')
  }

  function openCreate(
    mode: NonNullable<typeof editorMode>,
    defaults: Record<string, string> = {},
    sourceRows: MatricSourceRow[] = [],
    questions: ContentQuestion[] = [],
  ) {
    setEditorMode(mode)
    setDraft(defaults)
    setMatricSourceRows(sourceRows)
    setDraftQuestions(questions)
    setEditorOpen(true)
    setNotice('')
    setError('')
  }

  function relatedSubjectsForName(name: string) {
    return catalog.subjects.filter((s) => s.name === name)
  }

  function chaptersForSubjectId(id: string) {
    return catalog.chapters
      .filter((c) => c.subjectId === id)
      .sort((a, b) => a.order - b.order)
  }

  function emptyMatricRow(preferredGradeId?: string): MatricSourceRow {
    const related = subject
      ? relatedSubjectsForName(subject.name)
      : []
    const match =
      related.find((s) => s.gradeId === preferredGradeId) || related[0]
    const chs = match ? chaptersForSubjectId(match.id) : []
    return {
      key: `src-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
      gradeId: match?.gradeId || preferredGradeId || gradeId,
      subjectId: match?.id || subjectId || '',
      chapterId: chs[0]?.id || '',
      questionCount: '0',
    }
  }

  function questionDefaults() {
    return {
      gradeId,
      subjectId: subjectId || undefined,
      chapterId: chapterId || undefined,
    }
  }

  const questionBankScope = {
    grades: catalog.grades,
    subjects: catalog.subjects,
    chapters: catalog.chapters,
    subjectName: subject?.name,
    defaultGradeId: gradeId,
    defaultSubjectId: subjectId || undefined,
    defaultChapterId: chapterId || undefined,
  }

  function chapterSourcesFromQuestions(questions: ContentQuestion[]) {
    const map = new Map<
      string,
      { gradeId: string; subjectId: string; chapterId: string; questionCount: number }
    >()
    for (const q of questions) {
      if (!q.gradeId || !q.subjectId || !q.chapterId) continue
      const key = `${q.gradeId}|${q.subjectId}|${q.chapterId}`
      const prev = map.get(key)
      if (prev) prev.questionCount += 1
      else {
        map.set(key, {
          gradeId: q.gradeId,
          subjectId: q.subjectId,
          chapterId: q.chapterId,
          questionCount: 1,
        })
      }
    }
    return [...map.values()]
  }

  async function handleSave(event: FormEvent) {
    event.preventDefault()
    if (!editorMode) return
    setSaving(true)
    setError('')
    setNotice('')
    try {
      if (editorMode === 'grade') {
        const stream =
          draft.stream === 'natural' || draft.stream === 'social'
            ? draft.stream
            : null
        await upsertContentItem('grades', {
          id: draft.id || undefined,
          label: draft.label.trim(),
          stream,
        })
        setNotice('Grade saved')
      } else if (editorMode === 'subject' && gradeId) {
        await upsertContentItem('subjects', {
          id: draft.id || undefined,
          gradeId,
          name: draft.name.trim(),
          locked: draft.locked === 'true',
        })
        setNotice('Subject saved')
      } else if (editorMode === 'chapter' && subjectId) {
        const order = Number(draft.order || chapters.length + 1)
        await upsertContentItem('chapters', {
          id: draft.id || undefined,
          subjectId,
          title: draft.title.trim(),
          subtitle: draft.subtitle.trim() || 'Topics & pages',
          order,
        })
        setNotice('Chapter saved')
      } else if (editorMode === 'lesson' && chapterId) {
        await upsertContentItem('lessons', {
          id: draft.id || undefined,
          chapterId,
          title: draft.title.trim(),
          order: Number(draft.order || chapterLessons.length + 1),
          durationMinutes: Number(draft.durationMinutes || 10),
          status: (draft.status as PublishStatus) || 'draft',
        })
        setNotice('Lesson saved')
      } else if (editorMode === 'note' && chapterId) {
        if (!draft.lessonId) {
          setError('Pick a lesson — notes are classified by lesson.')
          setSaving(false)
          return
        }
        await upsertContentItem('notes', {
          id: draft.id || undefined,
          chapterId,
          lessonId: draft.lessonId,
          title: draft.title.trim(),
          bodyHtml: draft.bodyHtml || '<p></p>',
          status: (draft.status as PublishStatus) || 'draft',
        })
        setNotice('Note saved')
      } else if (editorMode === 'quiz' && chapterId) {
        const questions = draftQuestions.filter((q) => q.prompt.trim())
        await upsertContentItem('quizzes', {
          id: draft.id || undefined,
          chapterId,
          noteId: draft.noteId || null,
          title: draft.title.trim(),
          questionCount: questions.length,
          questions,
          status: (draft.status as PublishStatus) || 'draft',
        })
        setNotice('Quiz saved')
      } else if (editorMode === 'chapterExam' && chapterId) {
        const questionCount = questions.length
        await upsertContentItem('chapterExams', {
          id: draft.id || undefined,
          chapterId,
          title: draft.title.trim(),
          questionCount,
          durationMinutes: durationFromQuestionCount(questionCount),
          questions,
          status: (draft.status as PublishStatus) || 'draft',
        })
        setNotice('Chapter exam saved')
      } else if (editorMode === 'flashcardDeck' && chapterId) {
        await upsertContentItem('flashcardDecks', {
          id: draft.id || undefined,
          chapterId,
          title: draft.title.trim(),
          order: Number(draft.order || 1),
          status: (draft.status as PublishStatus) || 'draft',
        })
        setNotice('Flashcard deck saved')
      } else if (editorMode === 'flashcard' && chapterId) {
        await upsertContentItem('flashcards', {
          id: draft.id || undefined,
          chapterId,
          deckId: draft.deckId || flashDeckId,
          front: draft.front.trim(),
          back: draft.back.trim(),
          order: Number(draft.order || 1),
          status: (draft.status as PublishStatus) || 'draft',
        })
        setNotice('Flashcard saved')
      } else if (editorMode === 'subjectExam' && subjectId) {
        const examType = (draft.type as SubjectExamType) || 'mid'
        const questions = draftQuestions.filter((q) => q.prompt.trim())
        const derivedSources = chapterSourcesFromQuestions(questions)
        const chapterSources =
          examType === 'matric'
            ? derivedSources.length > 0
              ? derivedSources
              : matricSourceRows
                  .map((row) => ({
                    gradeId: row.gradeId,
                    subjectId: row.subjectId,
                    chapterId: row.chapterId,
                    questionCount: Number(row.questionCount || 0),
                  }))
                  .filter(
                    (row) =>
                      row.questionCount > 0 &&
                      row.chapterId &&
                      row.gradeId &&
                      row.subjectId,
                  )
            : undefined
        const sourcedTotal =
          chapterSources?.reduce((sum, row) => sum + row.questionCount, 0) ?? 0
        const questionCount =
          questions.length > 0
            ? questions.length
            : examType === 'matric' && sourcedTotal > 0
              ? sourcedTotal
              : 0
        await upsertContentItem('exams', {
          id: draft.id || undefined,
          subjectId,
          type: examType,
          title: draft.title.trim(),
          subtitle: draft.subtitle.trim() || '',
          questionCount,
          questions,
          durationMinutes: durationFromQuestionCount(questionCount),
          status: (draft.status as PublishStatus) || 'draft',
          ...(examType === 'matric'
            ? {
                year: Number(draft.year || new Date().getFullYear()),
                gradeId: draft.gradeId || gradeId,
                chapterSources: chapterSources ?? [],
              }
            : {}),
        })
        setNotice('Exam saved')
      }
      setEditorOpen(false)
      await refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save')
    } finally {
      setSaving(false)
    }
  }

  async function handleDelete(
    collection:
      | 'grades'
      | 'subjects'
      | 'chapters'
      | 'lessons'
      | 'notes'
      | 'quizzes'
      | 'chapterExams'
      | 'exams'
      | 'flashcardDecks'
      | 'flashcards',
    id: string,
    label: string,
  ) {
    if (!window.confirm(`Delete ${label}?`)) return
    setError('')
    try {
      await deleteContentItem(collection, id)
      if (collection === 'chapters' && chapterId === id) setChapterId(null)
      if (collection === 'grades' && gradeId === id) {
        setGradeId('')
        setSubjectId(null)
      }
      if (collection === 'subjects' && subjectId === id) setSubjectId(null)
      if (collection === 'flashcardDecks' && flashDeckId === id) {
        setFlashDeckId(null)
      }
      setNotice(`Deleted ${label}`)
      await refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not delete')
    }
  }

  const subjectExams = useMemo(() => {
    if (!subjectId) return []
    const typeMap: Record<SubjectTab, SubjectExamType | null> = {
      chapters: null,
      mid: 'mid',
      final: 'final',
      matric: 'matric',
    }
    const type = typeMap[subjectTab]
    if (!type) return []
    return catalog.exams.filter((e) => e.subjectId === subjectId && e.type === type)
  }, [catalog.exams, subjectId, subjectTab])

  const chapterLessons = catalog.lessons
    .filter((l) => l.chapterId === chapterId)
    .slice()
    .sort((a, b) => (a.order ?? 999) - (b.order ?? 999))
  const lessonTitleById = Object.fromEntries(
    chapterLessons.map((l) => [l.id, l.title]),
  )
  const chapterNotes = catalog.notes
    .filter((n) => n.chapterId === chapterId)
    .slice()
    .sort((a, b) => {
      const ao = chapterLessons.findIndex((l) => l.id === a.lessonId)
      const bo = chapterLessons.findIndex((l) => l.id === b.lessonId)
      const aOrder = ao === -1 ? 999 : ao
      const bOrder = bo === -1 ? 999 : bo
      if (aOrder !== bOrder) return aOrder - bOrder
      return a.title.localeCompare(b.title)
    })
  const chapterQuizzes = catalog.quizzes.filter((q) => q.chapterId === chapterId)
  const chapterExamItems = catalog.chapterExams.filter(
    (e) => e.chapterId === chapterId,
  )
  const chapterFlashcardDecks = (catalog.flashcardDecks || [])
    .filter((d) => d.chapterId === chapterId)
    .sort((a, b) => a.order - b.order)
  const flashDeck =
    (catalog.flashcardDecks || []).find((d) => d.id === flashDeckId) ?? null
  const chapterFlashcards = catalog.flashcards
    .filter((f) =>
      flashDeckId ? f.deckId === flashDeckId : f.chapterId === chapterId,
    )
    .sort((a, b) => a.order - b.order)

  return (
    <div className="page content-page">
      <PageHeader
        title="Content"
        subtitle="Manage grades → subjects → chapters → lessons, notes, quizzes, and exams."
      />

      {error ? <p className="content-banner content-banner--error">{error}</p> : null}
      {notice ? <p className="content-banner content-banner--ok">{notice}</p> : null}

      <div className="content-grades">
        <div className="content-grades__list">
          {catalog.grades.map((grade) => (
            <button
              key={grade.id}
              type="button"
              className={`content-grade-chip${gradeId === grade.id ? ' is-active' : ''}`}
              onClick={() => selectGrade(grade.id)}
            >
              {grade.label}
            </button>
          ))}
        </div>
        <div className="content-grades__actions">
          <button
            type="button"
            className="btn-ghost"
            onClick={() => openCreate('grade', { label: '', stream: '' })}
          >
            <Plus size={14} /> Grade
          </button>
          {gradeId ? (
            <>
              <button
                type="button"
                className="btn-ghost"
                onClick={() => {
                  const g = catalog.grades.find((x) => x.id === gradeId)
                  if (!g) return
                  openCreate('grade', {
                    id: g.id,
                    label: g.label,
                    stream: g.stream || '',
                  })
                }}
              >
                Edit grade
              </button>
              <button
                type="button"
                className="btn-ghost"
                onClick={() =>
                  handleDelete(
                    'grades',
                    gradeId,
                    catalog.grades.find((g) => g.id === gradeId)?.label ||
                      'grade',
                  )
                }
              >
                <Trash2 size={14} />
              </button>
            </>
          ) : null}
        </div>
      </div>

      {loading ? (
        <p className="text-muted">Loading catalog…</p>
      ) : (
        <div className="content-layout">
          <aside className="content-sidebar panel">
            <div className="content-sidebar__head">
              <GraduationCap size={16} />
              <strong>{gradeLabel} subjects</strong>
              <button
                type="button"
                className="btn-ghost"
                onClick={() =>
                  openCreate('subject', { name: '', locked: 'false' })
                }
              >
                <Plus size={14} />
              </button>
            </div>
            <ul className="content-subject-list">
              {subjects.map((item) => (
                <li key={item.id} className="content-subject-row">
                  <button
                    type="button"
                    className={`content-subject-item${subjectId === item.id ? ' is-active' : ''}`}
                    onClick={() => selectSubject(item.id)}
                  >
                    <span>{item.name}</span>
                    <span className="content-subject-item__meta">
                      {item.locked ? (
                        <Badge tone="warning">Locked</Badge>
                      ) : (
                        <Badge tone="success">Open</Badge>
                      )}
                      <ChevronRight size={14} />
                    </span>
                  </button>
                  <div className="content-subject-item__actions">
                    <button
                      type="button"
                      className="btn-ghost"
                      onClick={() =>
                        openCreate('subject', {
                          id: item.id,
                          name: item.name,
                          locked: item.locked ? 'true' : 'false',
                        })
                      }
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      className="btn-ghost"
                      onClick={() =>
                        handleDelete('subjects', item.id, item.name)
                      }
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </li>
              ))}
              {subjects.length === 0 ? (
                <li className="text-muted content-empty">No subjects for this grade.</li>
              ) : null}
            </ul>
          </aside>

          <section className="content-main panel">
            {!subject ? (
              <div className="content-empty-state">
                <Layers size={28} />
                <h3>Select a subject</h3>
                <p>Pick a subject on the left to manage chapters and exams.</p>
              </div>
            ) : (
              <>
                <div className="content-main__header">
                  <div>
                    <p className="content-crumb">
                      {gradeLabel} <ChevronRight size={12} /> {subject.name}
                      {chapter ? (
                        <>
                          {' '}
                          <ChevronRight size={12} /> {chapter.title}
                        </>
                      ) : null}
                    </p>
                    <h2>{chapter ? chapter.title : subject.name}</h2>
                  </div>
                </div>

                {!chapter ? (
                  <>
                    <div className="content-tabs">
                      {(
                        [
                          ['chapters', 'Chapters'],
                          ['mid', 'Mid exams'],
                          ['final', 'Final exams'],
                          ['matric', 'Matric exams'],
                        ] as const
                      ).map(([id, label]) => (
                        <button
                          key={id}
                          type="button"
                          className={`content-tab${subjectTab === id ? ' is-active' : ''}`}
                          onClick={() => {
                            setSubjectTab(id)
                            setChapterId(null)
                          }}
                        >
                          {label}
                        </button>
                      ))}
                    </div>

                    {subjectTab === 'chapters' ? (
                      <ChaptersPanel
                        chapters={chapters}
                        catalog={catalog}
                        onOpen={(id) => {
                          setChapterId(id)
                          setChapterTab('lessons')
                          setFlashDeckId(null)
                        }}
                        onAdd={() =>
                          openCreate('chapter', {
                            title: `Chapter ${chapters.length + 1}: `,
                            subtitle: '',
                            order: String(chapters.length + 1),
                          })
                        }
                        onEdit={(ch) =>
                          openCreate('chapter', {
                            id: ch.id,
                            title: ch.title,
                            subtitle: ch.subtitle,
                            order: String(ch.order),
                          })
                        }
                        onDelete={(ch) =>
                          handleDelete('chapters', ch.id, ch.title)
                        }
                      />
                    ) : (
                      <SubjectExamsPanel
                        type={subjectTab as Exclude<SubjectTab, 'chapters'>}
                        exams={subjectExams}
                        catalog={catalog}
                        onAdd={() => {
                          openCreate(
                            'subjectExam',
                            {
                              type: subjectTab,
                              title:
                                subjectTab === 'matric'
                                  ? `Matric Past Paper ${new Date().getFullYear()}`
                                  : '',
                              subtitle:
                                subjectTab === 'matric'
                                  ? 'National exam paper'
                                  : '',
                              questionCount: '40',
                              status: 'draft',
                              year: String(new Date().getFullYear()),
                              gradeId:
                                catalog.grades.find((g) =>
                                  g.id.includes('12'),
                                )?.id || gradeId,
                            },
                            subjectTab === 'matric' ? [emptyMatricRow()] : [],
                            [newQuestion(questionDefaults())],
                          )
                        }}
                        onEdit={(exam) => {
                          const rows: MatricSourceRow[] = (
                            exam.chapterSources ?? []
                          ).map((src, index) => {
                            const chapter = catalog.chapters.find(
                              (c) => c.id === src.chapterId,
                            )
                            const subjectRow = catalog.subjects.find(
                              (s) =>
                                s.id ===
                                (src.subjectId || chapter?.subjectId),
                            )
                            return {
                              key: `${exam.id}-${index}-${src.chapterId}`,
                              gradeId:
                                src.gradeId ||
                                subjectRow?.gradeId ||
                                gradeId,
                              subjectId:
                                src.subjectId ||
                                subjectRow?.id ||
                                subjectId ||
                                '',
                              chapterId: src.chapterId,
                              questionCount: String(src.questionCount),
                            }
                          })
                          openCreate(
                            'subjectExam',
                            {
                              id: exam.id,
                              type: exam.type,
                              title: exam.title,
                              subtitle: exam.subtitle,
                              questionCount: String(exam.questionCount),
                              status: exam.status,
                              year: String(
                                exam.year ?? new Date().getFullYear(),
                              ),
                              gradeId: exam.gradeId || gradeId,
                            },
                            rows,
                            exam.questions?.length
                              ? exam.questions
                              : [newQuestion(questionDefaults())],
                          )
                        }}
                        onDelete={(exam) =>
                          handleDelete('exams', exam.id, exam.title)
                        }
                      />
                    )}
                  </>
                ) : (
                  <>
                    <div className="content-tabs">
                      <button
                        type="button"
                        className="content-tab"
                        onClick={() => setChapterId(null)}
                      >
                        ← Chapters
                      </button>
                      {(
                        [
                          ['lessons', 'Lessons'],
                          ['notes', 'Notes'],
                          ['flashcards', 'Flashcards'],
                          ['quizzes', 'Quizzes'],
                          ['chapterExams', 'Chapter exams'],
                        ] as const
                      ).map(([id, label]) => (
                        <button
                          key={id}
                          type="button"
                          className={`content-tab${chapterTab === id ? ' is-active' : ''}`}
                          onClick={() => setChapterTab(id)}
                        >
                          {label}
                        </button>
                      ))}
                    </div>

                    {chapterTab === 'lessons' ? (
                      <SimpleRows
                        icon={<Video size={16} />}
                        title="Lessons"
                        empty="No lessons yet."
                        onAdd={() =>
                          openCreate('lesson', {
                            title: '',
                            order: String(chapterLessons.length + 1),
                            durationMinutes: '12',
                            status: 'draft',
                          })
                        }
                        rows={chapterLessons.map((item) => ({
                          id: item.id,
                          title: item.title,
                          meta: `#${item.order ?? '—'} · ${item.durationMinutes} min · ${item.updatedAt}`,
                          status: item.status,
                          onEdit: () =>
                            openCreate('lesson', {
                              id: item.id,
                              title: item.title,
                              order: String(item.order ?? 1),
                              durationMinutes: String(item.durationMinutes),
                              status: item.status,
                            }),
                          onDelete: () =>
                            handleDelete('lessons', item.id, item.title),
                        }))}
                      />
                    ) : null}

                    {chapterTab === 'notes' ? (
                      <SimpleRows
                        icon={<FileText size={16} />}
                        title="Notes"
                        empty={
                          chapterLessons.length === 0
                            ? 'Add lessons first, then create one note per lesson.'
                            : 'No notes yet. Add a note linked to a lesson.'
                        }
                        onAdd={() =>
                          openCreate('note', {
                            lessonId: chapterLessons[0]?.id || '',
                            title: chapterLessons[0]
                              ? `${chapterLessons[0].title} — Notes`
                              : 'Lesson notes',
                            bodyHtml:
                              '<div class="section-label">1.1</div><h2>Topic</h2><p class="lead">One-line hook.</p><div class="key-term"><span class="kt-label">Key term</span><strong>Term.</strong> Definition.</div>',
                            status: 'draft',
                          })
                        }
                        rows={chapterNotes.map((item) => ({
                          id: item.id,
                          title: item.title,
                          meta: `${lessonTitleById[item.lessonId] || 'No lesson'} · ${item.updatedAt}`,
                          status: item.status,
                          onEdit: () =>
                            openCreate('note', {
                              id: item.id,
                              lessonId: item.lessonId || '',
                              title: item.title,
                              bodyHtml: item.bodyHtml,
                              status: item.status,
                            }),
                          onDelete: () =>
                            handleDelete('notes', item.id, item.title),
                        }))}
                      />
                    ) : null}

                    {chapterTab === 'flashcards' ? (
                      flashDeckId && flashDeck ? (
                        <SimpleRows
                          icon={<StickyNote size={16} />}
                          title={flashDeck.title}
                          empty="No cards in this deck yet."
                          toolbarLeft={
                            <button
                              type="button"
                              className="btn-ghost"
                              onClick={() => setFlashDeckId(null)}
                            >
                              ← Decks
                            </button>
                          }
                          onAdd={() =>
                            openCreate('flashcard', {
                              deckId: flashDeck.id,
                              front: '',
                              back: '',
                              order: String(chapterFlashcards.length + 1),
                              status: 'draft',
                            })
                          }
                          rows={chapterFlashcards.map((item) => ({
                            id: item.id,
                            title: item.front,
                            meta: `Answer: ${item.back} · #${item.order}`,
                            status: item.status,
                            onEdit: () =>
                              openCreate('flashcard', {
                                id: item.id,
                                deckId: item.deckId || flashDeck.id,
                                front: item.front,
                                back: item.back,
                                order: String(item.order),
                                status: item.status,
                              }),
                            onDelete: () =>
                              handleDelete('flashcards', item.id, item.front),
                          }))}
                        />
                      ) : (
                        <SimpleRows
                          icon={<StickyNote size={16} />}
                          title="Flashcard decks"
                          empty="No decks yet. Add a deck, then add cards inside it."
                          onAdd={() =>
                            openCreate('flashcardDeck', {
                              title: 'Key Terms Deck',
                              order: String(chapterFlashcardDecks.length + 1),
                              status: 'draft',
                            })
                          }
                          rows={chapterFlashcardDecks.map((item) => ({
                            id: item.id,
                            title: item.title,
                            meta: `${catalog.flashcards.filter((f) => f.deckId === item.id).length} cards · ${item.updatedAt}`,
                            status: item.status,
                            onOpen: () => setFlashDeckId(item.id),
                            onEdit: () =>
                              openCreate('flashcardDeck', {
                                id: item.id,
                                title: item.title,
                                order: String(item.order),
                                status: item.status,
                              }),
                            onDelete: () =>
                              handleDelete(
                                'flashcardDecks',
                                item.id,
                                item.title,
                              ),
                          }))}
                        />
                      )
                    ) : null}

                    {chapterTab === 'quizzes' ? (
                      <SimpleRows
                        icon={<ClipboardList size={16} />}
                        title="Quizzes"
                        empty="No quizzes yet. Add a quiz, then add multiple-choice questions."
                        onAdd={() =>
                          openCreate(
                            'quiz',
                            {
                              title: '',
                              noteId: '',
                              status: 'draft',
                            },
                            [],
                            [newQuestion(questionDefaults())],
                          )
                        }
                        rows={chapterQuizzes.map((item) => ({
                          id: item.id,
                          title: item.title,
                          meta: `${item.questions?.length ?? item.questionCount} questions · ${item.updatedAt}`,
                          status: item.status,
                          onEdit: () =>
                            openCreate(
                              'quiz',
                              {
                                id: item.id,
                                title: item.title,
                                noteId: item.noteId || '',
                                status: item.status,
                              },
                              [],
                              item.questions?.length
                                ? item.questions
                                : [newQuestion(questionDefaults())],
                            ),
                          onDelete: () =>
                            handleDelete('quizzes', item.id, item.title),
                        }))}
                      />
                    ) : null}

                    {chapterTab === 'chapterExams' ? (
                      <SimpleRows
                        icon={<BookOpen size={16} />}
                        title="Chapter exams"
                        empty="No chapter exams yet."
                        onAdd={() =>
                          openCreate(
                            'chapterExam',
                            {
                              title: `${chapter.title} Practice Exam`,
                              status: 'draft',
                            },
                            [],
                            [newQuestion(questionDefaults())],
                          )
                        }
                        rows={chapterExamItems.map((item) => ({
                          id: item.id,
                          title: item.title,
                          meta: `${item.questions?.length ?? item.questionCount} Q · ${item.durationMinutes} min · ${item.updatedAt}`,
                          status: item.status,
                          onEdit: () =>
                            openCreate(
                              'chapterExam',
                              {
                                id: item.id,
                                title: item.title,
                                status: item.status,
                              },
                              [],
                              item.questions?.length
                                ? item.questions
                                : [newQuestion(questionDefaults())],
                            ),
                          onDelete: () =>
                            handleDelete('chapterExams', item.id, item.title),
                        }))}
                      />
                    ) : null}
                  </>
                )}
              </>
            )}
          </section>
        </div>
      )}

      {editorOpen && editorMode ? (
        <div className="content-modal-backdrop" role="presentation">
          <form className="content-modal panel" onSubmit={handleSave}>
            <h3>{draft.id ? 'Edit' : 'Add'} {editorLabel(editorMode)}</h3>

            {editorMode === 'grade' ? (
              <>
                <label>
                  Label
                  <input
                    value={draft.label || ''}
                    onChange={(e) =>
                      setDraft((d) => ({ ...d, label: e.target.value }))
                    }
                    placeholder="Grade 10"
                    required
                  />
                </label>
                <label>
                  Stream
                  <select
                    value={draft.stream || ''}
                    onChange={(e) =>
                      setDraft((d) => ({ ...d, stream: e.target.value }))
                    }
                  >
                    <option value="">None (Grade 9–10)</option>
                    <option value="natural">Natural</option>
                    <option value="social">Social</option>
                  </select>
                </label>
              </>
            ) : null}

            {editorMode === 'subject' ? (
              <>
                <label>
                  Name
                  <input
                    value={draft.name || ''}
                    onChange={(e) =>
                      setDraft((d) => ({ ...d, name: e.target.value }))
                    }
                    placeholder="Biology"
                    required
                  />
                </label>
                <label>
                  Access
                  <select
                    value={draft.locked || 'false'}
                    onChange={(e) =>
                      setDraft((d) => ({ ...d, locked: e.target.value }))
                    }
                  >
                    <option value="false">Open</option>
                    <option value="true">Locked</option>
                  </select>
                </label>
              </>
            ) : null}

            {editorMode !== 'flashcard' &&
            editorMode !== 'grade' &&
            editorMode !== 'subject' ? (
              <label>
                Title
                <input
                  value={draft.title || ''}
                  onChange={(e) => setDraft((d) => ({ ...d, title: e.target.value }))}
                  required
                />
              </label>
            ) : null}

            {editorMode === 'flashcardDeck' ? (
              <label>
                Order
                <input
                  type="number"
                  min={1}
                  value={draft.order || '1'}
                  onChange={(e) =>
                    setDraft((d) => ({ ...d, order: e.target.value }))
                  }
                />
              </label>
            ) : null}

            {editorMode === 'chapter' ? (
              <>
                <label>
                  Subtitle
                  <input
                    value={draft.subtitle || ''}
                    onChange={(e) =>
                      setDraft((d) => ({ ...d, subtitle: e.target.value }))
                    }
                  />
                </label>
                <label>
                  Order
                  <input
                    type="number"
                    min={1}
                    value={draft.order || '1'}
                    onChange={(e) =>
                      setDraft((d) => ({ ...d, order: e.target.value }))
                    }
                  />
                </label>
              </>
            ) : null}

            {editorMode === 'lesson' ? (
              <>
                <label>
                  Order
                  <input
                    type="number"
                    min={1}
                    value={draft.order || '1'}
                    onChange={(e) =>
                      setDraft((d) => ({ ...d, order: e.target.value }))
                    }
                  />
                </label>
                <label>
                  Duration (minutes)
                  <input
                    type="number"
                    min={1}
                    value={draft.durationMinutes || '10'}
                    onChange={(e) =>
                      setDraft((d) => ({ ...d, durationMinutes: e.target.value }))
                    }
                  />
                </label>
              </>
            ) : null}

            {editorMode === 'note' ? (
              <>
                <label>
                  Lesson
                  <select
                    required
                    value={draft.lessonId || ''}
                    onChange={(e) => {
                      const lessonId = e.target.value
                      const lesson = chapterLessons.find((l) => l.id === lessonId)
                      setDraft((d) => ({
                        ...d,
                        lessonId,
                        title:
                          d.title?.includes('— Notes') || !d.title
                            ? lesson
                              ? `${lesson.title} — Notes`
                              : d.title
                            : d.title,
                      }))
                    }}
                  >
                    <option value="">Select lesson…</option>
                    {chapterLessons.map((l) => (
                      <option key={l.id} value={l.id}>
                        {l.order != null ? `${l.order}. ` : ''}
                        {l.title}
                      </option>
                    ))}
                  </select>
                </label>
                <RichContentFields
                  label="Body (HTML + KaTeX)"
                  value={draft.bodyHtml || ''}
                  onChange={(bodyHtml) => setDraft((d) => ({ ...d, bodyHtml }))}
                  rows={10}
                  htmlMode
                  placeholder="<h2>Topic</h2><p>Explain with \$F=ma\$ or upload a diagram…</p>"
                />
              </>
            ) : null}

            {editorMode === 'flashcard' ? (
              <>
                <RichContentFields
                  label="Front (question / prompt)"
                  value={draft.front || ''}
                  onChange={(front) => setDraft((d) => ({ ...d, front }))}
                  rows={3}
                  htmlMode={false}
                  required
                />
                <RichContentFields
                  label="Back (answer)"
                  value={draft.back || ''}
                  onChange={(back) => setDraft((d) => ({ ...d, back }))}
                  rows={3}
                  htmlMode={false}
                  required
                />
                <label>
                  Order
                  <input
                    type="number"
                    min={1}
                    value={draft.order || '1'}
                    onChange={(e) =>
                      setDraft((d) => ({ ...d, order: e.target.value }))
                    }
                  />
                </label>
              </>
            ) : null}

            {editorMode === 'quiz' || editorMode === 'chapterExam' ? (
              <QuestionBankEditor
                questions={draftQuestions}
                onChange={setDraftQuestions}
                scope={questionBankScope}
              />
            ) : null}

            {editorMode === 'subjectExam' ? (
              <>
                <label>
                  Type
                  <select
                    value={draft.type || 'mid'}
                    onChange={(e) =>
                      setDraft((d) => ({ ...d, type: e.target.value }))
                    }
                  >
                    <option value="mid">Mid</option>
                    <option value="final">Final</option>
                    <option value="matric">Matric</option>
                  </select>
                </label>
                <label>
                  Subtitle
                  <input
                    value={draft.subtitle || ''}
                    onChange={(e) =>
                      setDraft((d) => ({ ...d, subtitle: e.target.value }))
                    }
                  />
                </label>
                {(draft.type || 'mid') === 'matric' ? (
                  <>
                    <label>
                      Year
                      <input
                        type="number"
                        min={1990}
                        max={2100}
                        value={draft.year || ''}
                        onChange={(e) =>
                          setDraft((d) => ({ ...d, year: e.target.value }))
                        }
                        required
                      />
                    </label>
                    <label>
                      Sitting grade
                      <select
                        value={draft.gradeId || gradeId}
                        onChange={(e) =>
                          setDraft((d) => ({ ...d, gradeId: e.target.value }))
                        }
                        required
                      >
                        {catalog.grades.map((g) => (
                          <option key={g.id} value={g.id}>
                            {g.label}
                          </option>
                        ))}
                      </select>
                    </label>
                    <div className="content-matric-sources">
                      <p className="content-matric-sources__title">
                        Grade / chapter mix
                      </p>
                      <p className="content-matric-sources__hint">
                        Set grade + chapter on each question below. This summary
                        updates automatically.
                      </p>
                      {(() => {
                        const mix = chapterSourcesFromQuestions(
                          draftQuestions.filter((q) => q.prompt.trim()),
                        )
                        if (mix.length === 0) {
                          return (
                            <p className="text-muted">
                              No tagged questions yet.
                            </p>
                          )
                        }
                        return (
                          <ul className="content-source-list">
                            {mix.map((src) => {
                              const g =
                                catalog.grades.find((x) => x.id === src.gradeId)
                                  ?.label ?? src.gradeId
                              const ch =
                                catalog.chapters.find(
                                  (x) => x.id === src.chapterId,
                                )?.title ?? src.chapterId
                              return (
                                <li key={`${src.gradeId}-${src.chapterId}`}>
                                  {g} · {ch} · {src.questionCount}Q
                                </li>
                              )
                            })}
                          </ul>
                        )
                      })()}
                    </div>
                  </>
                ) : null}

                <QuestionBankEditor
                  questions={draftQuestions}
                  onChange={setDraftQuestions}
                  scope={questionBankScope}
                />
              </>
            ) : null}

            {editorMode === 'chapterExam' || editorMode === 'subjectExam' ? (
              <p className="content-duration-note">
                Duration:{' '}
                <strong>
                  {durationFromQuestionCount(
                    (() => {
                      const fromBank = draftQuestions.filter((q) =>
                        q.prompt.trim(),
                      ).length
                      if (editorMode === 'chapterExam' || fromBank > 0) {
                        return fromBank
                      }
                      if ((draft.type || 'mid') === 'matric') {
                        return matricSourceRows.reduce(
                          (sum, row) => sum + Number(row.questionCount || 0),
                          0,
                        )
                      }
                      return Number(draft.questionCount || 0)
                    })(),
                  )}{' '}
                  min
                </strong>{' '}
                ({MINUTES_PER_QUESTION} min per question)
              </p>
            ) : null}

            {editorMode !== 'chapter' &&
            editorMode !== 'grade' &&
            editorMode !== 'subject' ? (
              <label>
                Status
                <select
                  value={draft.status || 'draft'}
                  onChange={(e) =>
                    setDraft((d) => ({ ...d, status: e.target.value }))
                  }
                >
                  <option value="draft">Draft</option>
                  <option value="published">Published</option>
                </select>
              </label>
            ) : null}

            <div className="content-modal__actions">
              <button
                type="button"
                className="btn-ghost"
                onClick={() => setEditorOpen(false)}
              >
                Cancel
              </button>
              <button type="submit" className="btn-primary" disabled={saving}>
                {saving ? 'Saving…' : 'Save'}
              </button>
            </div>
          </form>
        </div>
      ) : null}
    </div>
  )
}

function editorLabel(mode: string) {
  switch (mode) {
    case 'chapter':
      return 'chapter'
    case 'lesson':
      return 'lesson'
    case 'note':
      return 'note'
    case 'quiz':
      return 'quiz'
    case 'flashcard':
      return 'flashcard'
    case 'flashcardDeck':
      return 'flashcard deck'
    case 'grade':
      return 'grade'
    case 'subject':
      return 'subject'
    case 'chapterExam':
      return 'chapter exam'
    case 'subjectExam':
      return 'exam'
    default:
      return 'item'
  }
}

function ChaptersPanel({
  chapters,
  catalog,
  onOpen,
  onAdd,
  onEdit,
  onDelete,
}: {
  chapters: ContentChapter[]
  catalog: ContentCatalog
  onOpen: (id: string) => void
  onAdd: () => void
  onEdit: (chapter: ContentChapter) => void
  onDelete: (chapter: ContentChapter) => void
}) {
  return (
    <div>
      <div className="content-panel-toolbar">
        <div>
          <h3>Chapters</h3>
          <p className="content-hint">
            Click <strong>Open</strong> on a chapter to add notes, flashcards,
            quizzes, and question banks.
          </p>
        </div>
        <button type="button" className="btn-primary" onClick={onAdd}>
          <Plus size={14} /> Add chapter
        </button>
      </div>
      {chapters.length === 0 ? (
        <p className="text-muted">No chapters yet.</p>
      ) : (
        <div className="data-table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>#</th>
                <th>Chapter</th>
                <th>Lessons</th>
                <th>Notes</th>
                <th>Decks</th>
                <th>Quizzes</th>
                <th>Ch. exams</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {chapters.map((ch) => (
                <tr key={ch.id}>
                  <td>{ch.order}</td>
                  <td>
                    <button
                      type="button"
                      className="content-link"
                      onClick={() => onOpen(ch.id)}
                    >
                      {ch.title}
                    </button>
                    <div className="text-muted" style={{ fontSize: 12 }}>
                      {ch.subtitle}
                    </div>
                  </td>
                  <td>
                    {catalog.lessons.filter((l) => l.chapterId === ch.id).length}
                  </td>
                  <td>
                    {catalog.notes.filter((n) => n.chapterId === ch.id).length}
                  </td>
                  <td>
                    {(catalog.flashcardDecks || []).filter(
                      (d) => d.chapterId === ch.id,
                    ).length}
                  </td>
                  <td>
                    {catalog.quizzes.filter((q) => q.chapterId === ch.id).length}
                  </td>
                  <td>
                    {
                      catalog.chapterExams.filter((e) => e.chapterId === ch.id)
                        .length
                    }
                  </td>
                  <td>
                    <div className="data-table__actions">
                      <button
                        type="button"
                        className="btn-primary"
                        onClick={() => onOpen(ch.id)}
                      >
                        Open
                      </button>
                      <button type="button" className="btn-ghost" onClick={() => onEdit(ch)}>
                        Edit
                      </button>
                      <button type="button" className="btn-ghost" onClick={() => onDelete(ch)}>
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

function SubjectExamsPanel({
  type,
  exams,
  catalog,
  onAdd,
  onEdit,
  onDelete,
}: {
  type: 'mid' | 'final' | 'matric'
  exams: ContentSubjectExam[]
  catalog: ContentCatalog
  onAdd: () => void
  onEdit: (exam: ContentSubjectExam) => void
  onDelete: (exam: ContentSubjectExam) => void
}) {
  const title =
    type === 'mid' ? 'Mid exams' : type === 'final' ? 'Final exams' : 'Matric exams'
  const isMatric = type === 'matric'
  const gradeLabel = (id?: string) =>
    catalog.grades.find((g) => g.id === id)?.label ?? '—'
  const chapterTitle = (id: string) =>
    catalog.chapters.find((c) => c.id === id)?.title ?? id

  const sourcesByGrade = (exam: ContentSubjectExam) => {
    const map = new Map<string, number>()
    for (const src of exam.chapterSources ?? []) {
      const label = gradeLabel(src.gradeId)
      map.set(label, (map.get(label) ?? 0) + src.questionCount)
    }
    return [...map.entries()]
  }

  return (
    <div>
      <div className="content-panel-toolbar">
        <h3>{title}</h3>
        <button type="button" className="btn-primary" onClick={onAdd}>
          <Plus size={14} /> Add {type} exam
        </button>
      </div>
      {exams.length === 0 ? (
        <p className="text-muted">No {type} exams yet.</p>
      ) : (
        <div className="data-table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>Title</th>
                {isMatric ? <th>Year</th> : null}
                {isMatric ? <th>Sitting grade</th> : null}
                {isMatric ? <th>Sources</th> : null}
                <th>Questions</th>
                <th>Duration</th>
                <th>Status</th>
                <th>Updated</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {exams.map((exam) => (
                <tr key={exam.id}>
                  <td>
                    <div>{exam.title}</div>
                    <div className="text-muted" style={{ fontSize: 12 }}>
                      {exam.subtitle}
                    </div>
                  </td>
                  {isMatric ? <td>{exam.year ?? '—'}</td> : null}
                  {isMatric ? <td>{gradeLabel(exam.gradeId)}</td> : null}
                  {isMatric ? (
                    <td>
                      {(exam.chapterSources ?? []).length === 0 ? (
                        <span className="text-muted">No sources</span>
                      ) : (
                        <>
                          <ul className="content-source-list">
                            {sourcesByGrade(exam).map(([g, count]) => (
                              <li key={g}>
                                {g} · {count}Q
                              </li>
                            ))}
                          </ul>
                          <details className="content-source-details">
                            <summary>Chapters</summary>
                            <ul className="content-source-list">
                              {(exam.chapterSources ?? []).map((src) => (
                                <li key={`${src.gradeId}-${src.chapterId}`}>
                                  {gradeLabel(src.gradeId)} ·{' '}
                                  {chapterTitle(src.chapterId)} ·{' '}
                                  {src.questionCount}Q
                                </li>
                              ))}
                            </ul>
                          </details>
                        </>
                      )}
                    </td>
                  ) : null}
                  <td>
                    {exam.questions?.length || exam.questionCount}
                  </td>
                  <td>
                    {exam.durationMinutes} min
                    <div className="text-muted" style={{ fontSize: 11 }}>
                      {MINUTES_PER_QUESTION} min/Q
                    </div>
                  </td>
                  <td>
                    <Badge tone={exam.status === 'published' ? 'success' : 'neutral'}>
                      {exam.status}
                    </Badge>
                  </td>
                  <td className="text-muted">{exam.updatedAt}</td>
                  <td>
                    <div className="data-table__actions">
                      <button type="button" className="btn-ghost" onClick={() => onEdit(exam)}>
                        Edit
                      </button>
                      <button type="button" className="btn-ghost" onClick={() => onDelete(exam)}>
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

function SimpleRows({
  icon,
  title,
  empty,
  onAdd,
  rows,
  toolbarLeft,
}: {
  icon: ReactNode
  title: string
  empty: string
  onAdd: () => void
  toolbarLeft?: ReactNode
  rows: Array<{
    id: string
    title: string
    meta: string
    status: PublishStatus
    onOpen?: () => void
    onEdit: () => void
    onDelete: () => void
  }>
}) {
  return (
    <div>
      <div className="content-panel-toolbar">
        <div className="content-panel-toolbar__left">
          {toolbarLeft}
          <h3>
            <span className="content-panel-toolbar__icon">{icon}</span>
            {title}
          </h3>
        </div>
        <button type="button" className="btn-primary" onClick={onAdd}>
          <Plus size={14} /> Add
        </button>
      </div>
      {rows.length === 0 ? (
        <p className="text-muted">{empty}</p>
      ) : (
        <ul className="content-row-list">
          {rows.map((row) => (
            <li key={row.id} className="content-row">
              <div>
                <strong>{row.title}</strong>
                <p className="text-muted">{row.meta}</p>
              </div>
              <div className="content-row__actions">
                <Badge tone={row.status === 'published' ? 'success' : 'neutral'}>
                  {row.status}
                </Badge>
                {row.onOpen ? (
                  <button
                    type="button"
                    className="btn-primary"
                    onClick={row.onOpen}
                  >
                    Open
                  </button>
                ) : null}
                <button type="button" className="btn-ghost" onClick={row.onEdit}>
                  Edit
                </button>
                <button type="button" className="btn-ghost" onClick={row.onDelete}>
                  <Trash2 size={14} />
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
