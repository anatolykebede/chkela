import { Plus, Trash2 } from 'lucide-react'
import { useEffect, useMemo } from 'react'
import type {
  ContentChapter,
  ContentGrade,
  ContentQuestion,
  ContentSubject,
} from '../lib/contentApi'
import { RichContentFields } from './RichContentFields'
import './RichContentFields.css'

export function newQuestion(
  defaults: Partial<
    Pick<ContentQuestion, 'gradeId' | 'subjectId' | 'chapterId'>
  > = {},
): ContentQuestion {
  return {
    id: `q-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
    prompt: '',
    options: ['', '', '', ''],
    correctIndex: 0,
    explanation: '',
    gradeId: defaults.gradeId || '',
    subjectId: defaults.subjectId || '',
    chapterId: defaults.chapterId || '',
  }
}

export type QuestionBankScope = {
  grades: ContentGrade[]
  subjects: ContentSubject[]
  chapters: ContentChapter[]
  /** Limit grade/chapter pickers to this subject family (e.g. "Biology"). */
  subjectName?: string
  /** Prefill new questions / empty fields. */
  defaultGradeId?: string
  defaultSubjectId?: string
  defaultChapterId?: string
}

type QuestionBankEditorProps = {
  questions: ContentQuestion[]
  onChange: (next: ContentQuestion[]) => void
  scope: QuestionBankScope
}

/** Inline MCQ editor with per-question grade + chapter tags. */
export function QuestionBankEditor({
  questions,
  onChange,
  scope,
}: QuestionBankEditorProps) {
  const relatedSubjects = useMemo(
    () =>
      scope.subjectName
        ? scope.subjects.filter((s) => s.name === scope.subjectName)
        : scope.subjects,
    [scope.subjectName, scope.subjects],
  )

  const gradeOptions = useMemo(
    () =>
      scope.grades.filter((g) =>
        relatedSubjects.some((s) => s.gradeId === g.id),
      ),
    [scope.grades, relatedSubjects],
  )

  function subjectForGrade(gradeId: string) {
    return (
      relatedSubjects.find((s) => s.gradeId === gradeId) || relatedSubjects[0]
    )
  }

  function chaptersForSubject(subjectId: string) {
    return scope.chapters
      .filter((c) => c.subjectId === subjectId)
      .sort((a, b) => a.order - b.order)
  }

  function ensurePlacement(q: ContentQuestion): ContentQuestion {
    let gradeId = q.gradeId || scope.defaultGradeId || gradeOptions[0]?.id || ''
    let subject =
      relatedSubjects.find((s) => s.id === q.subjectId) ||
      subjectForGrade(gradeId)
    if (subject && subject.gradeId !== gradeId) {
      subject = subjectForGrade(gradeId)
    }
    const subjectId = subject?.id || scope.defaultSubjectId || ''
    if (subject) gradeId = subject.gradeId
    const chapterOptions = chaptersForSubject(subjectId)
    const chapterId =
      chapterOptions.find((c) => c.id === q.chapterId)?.id ||
      (scope.defaultChapterId &&
      chapterOptions.some((c) => c.id === scope.defaultChapterId)
        ? scope.defaultChapterId
        : '') ||
      chapterOptions[0]?.id ||
      ''
    return { ...q, gradeId, subjectId, chapterId }
  }

  useEffect(() => {
    if (questions.length === 0) return
    const next = questions.map(ensurePlacement)
    const changed = next.some(
      (q, i) =>
        q.gradeId !== questions[i].gradeId ||
        q.subjectId !== questions[i].subjectId ||
        q.chapterId !== questions[i].chapterId,
    )
    if (changed) onChange(next)
    // Hydrate missing grade/chapter when opening or scope defaults change.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    questions.length,
    scope.defaultGradeId,
    scope.defaultSubjectId,
    scope.defaultChapterId,
    scope.subjectName,
  ])

  function update(index: number, patch: Partial<ContentQuestion>) {
    onChange(
      questions.map((q, i) => {
        if (i !== index) return q
        return ensurePlacement({ ...q, ...patch })
      }),
    )
  }

  function setGrade(index: number, gradeId: string) {
    const subject = subjectForGrade(gradeId)
    const chapterOptions = subject ? chaptersForSubject(subject.id) : []
    update(index, {
      gradeId,
      subjectId: subject?.id || '',
      chapterId: chapterOptions[0]?.id || '',
    })
  }

  function setChapter(index: number, chapterId: string) {
    const chapter = scope.chapters.find((c) => c.id === chapterId)
    const subject = scope.subjects.find((s) => s.id === chapter?.subjectId)
    update(index, {
      chapterId,
      subjectId: subject?.id || questions[index]?.subjectId || '',
      gradeId: subject?.gradeId || questions[index]?.gradeId || '',
    })
  }

  function updateOption(qIndex: number, optIndex: number, value: string) {
    const next = questions.map((q, i) => {
      if (i !== qIndex) return q
      const options = [...q.options]
      options[optIndex] = value
      return { ...q, options }
    })
    onChange(next)
  }

  function addQuestion() {
    onChange([
      ...questions,
      ensurePlacement(
        newQuestion({
          gradeId: scope.defaultGradeId || gradeOptions[0]?.id,
          subjectId: scope.defaultSubjectId,
          chapterId: scope.defaultChapterId,
        }),
      ),
    ])
  }

  return (
    <div className="content-question-bank">
      <div className="content-question-bank__head">
        <div>
          <p className="content-matric-sources__title">Questions</p>
          <p className="content-matric-sources__hint">
            Each question needs a grade and chapter so you can build papers by
            topic.
          </p>
        </div>
        <button type="button" className="btn-ghost" onClick={addQuestion}>
          <Plus size={14} /> Add question
        </button>
      </div>
      {questions.length === 0 ? (
        <p className="text-muted">No questions yet — add the first one.</p>
      ) : (
        <div className="content-question-bank__list">
          {questions.map((raw, index) => {
            const q = ensurePlacement(raw)
            const chapterOptions = chaptersForSubject(q.subjectId)
            return (
              <div key={q.id} className="content-question-card">
                <div className="content-question-card__top">
                  <strong>Q{index + 1}</strong>
                  <button
                    type="button"
                    className="btn-ghost"
                    onClick={() =>
                      onChange(questions.filter((_, i) => i !== index))
                    }
                  >
                    <Trash2 size={14} />
                  </button>
                </div>

                <div className="content-question-placement">
                  <label>
                    Grade
                    <select
                      value={q.gradeId}
                      onChange={(e) => setGrade(index, e.target.value)}
                      required
                    >
                      {gradeOptions.length === 0 ? (
                        <option value="">No grades</option>
                      ) : (
                        gradeOptions.map((g) => (
                          <option key={g.id} value={g.id}>
                            {g.label}
                          </option>
                        ))
                      )}
                    </select>
                  </label>
                  <label>
                    Chapter
                    <select
                      value={q.chapterId}
                      onChange={(e) => setChapter(index, e.target.value)}
                      required
                    >
                      {chapterOptions.length === 0 ? (
                        <option value="">No chapters</option>
                      ) : (
                        chapterOptions.map((ch) => (
                          <option key={ch.id} value={ch.id}>
                            {ch.title}
                          </option>
                        ))
                      )}
                    </select>
                  </label>
                </div>

                <RichContentFields
                  label="Prompt (KaTeX + media OK)"
                  value={q.prompt}
                  onChange={(prompt) => update(index, { prompt })}
                  rows={3}
                  htmlMode={false}
                  required
                  placeholder="e.g. Solve \$x^2-4=0\$"
                />
                <div className="content-question-options">
                  {q.options.map((opt, optIndex) => (
                    <label key={optIndex} className="content-question-option">
                      <input
                        type="radio"
                        name={`correct-${q.id}`}
                        checked={q.correctIndex === optIndex}
                        onChange={() =>
                          update(index, { correctIndex: optIndex })
                        }
                      />
                      <span>Option {optIndex + 1}</span>
                      <input
                        value={opt}
                        onChange={(e) =>
                          updateOption(index, optIndex, e.target.value)
                        }
                        placeholder="Plain text or $...$"
                        required
                      />
                    </label>
                  ))}
                </div>
                <label>
                  Explanation
                  <input
                    value={q.explanation}
                    onChange={(e) =>
                      update(index, { explanation: e.target.value })
                    }
                  />
                </label>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
