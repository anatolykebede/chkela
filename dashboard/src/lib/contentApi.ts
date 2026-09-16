import { adminFetch } from './adminAuth'
import { sanitizeCmsHtml } from './sanitizeHtml'

export type PublishStatus = 'draft' | 'published'
export type SubjectExamType = 'mid' | 'final' | 'matric'
export type GradeStream = 'natural' | 'social' | null

export type ContentGrade = {
  id: string
  label: string
  stream: GradeStream
}

export type ContentSubject = {
  id: string
  name: string
  gradeId: string
  locked: boolean
}

export type ContentChapter = {
  id: string
  subjectId: string
  title: string
  subtitle: string
  order: number
}

export type ContentLesson = {
  id: string
  chapterId: string
  title: string
  /** Display order within the chapter (1-based). */
  order?: number
  durationMinutes: number
  status: PublishStatus
  updatedAt: string
}

export type ContentNote = {
  id: string
  chapterId: string
  /** Lesson this note belongs to — required for new Grade notes. */
  lessonId?: string
  title: string
  bodyHtml: string
  status: PublishStatus
  updatedAt: string
}

/** Multiple-choice item used by quizzes, chapter exams, and subject exams. */
export type ContentQuestion = {
  id: string
  prompt: string
  options: string[]
  correctIndex: number
  explanation: string
  /** Grade this question belongs to (e.g. grade-9). */
  gradeId?: string
  /** Subject instance in that grade (e.g. bio-g9). */
  subjectId?: string
  /** Chapter this question is tagged to. */
  chapterId?: string
}

export type ContentQuiz = {
  id: string
  chapterId: string
  noteId: string | null
  title: string
  questionCount: number
  questions?: ContentQuestion[]
  status: PublishStatus
  updatedAt: string
}

export type ContentChapterExam = {
  id: string
  chapterId: string
  title: string
  questionCount: number
  durationMinutes: number
  questions?: ContentQuestion[]
  status: PublishStatus
  updatedAt: string
}

export type ContentFlashcardDeck = {
  id: string
  chapterId: string
  title: string
  order: number
  status: PublishStatus
  updatedAt: string
}

export type ContentFlashcard = {
  id: string
  chapterId: string
  /** Parent deck — cards belong to a deck within a chapter. */
  deckId: string
  front: string
  back: string
  order: number
  status: PublishStatus
  updatedAt: string
}

export type MatricChapterSource = {
  /** Grade the questions come from (e.g. Grade 9). */
  gradeId: string
  /** Subject instance in that grade (e.g. bio-g9). */
  subjectId: string
  chapterId: string
  questionCount: number
}

export type ContentSubjectExam = {
  id: string
  subjectId: string
  type: SubjectExamType
  title: string
  subtitle: string
  questionCount: number
  durationMinutes: number
  status: PublishStatus
  updatedAt: string
  /** Multiple-choice questions for this paper. */
  questions?: ContentQuestion[]
  /** Matric paper year (e.g. 2018). */
  year?: number
  /** Grade of students who sit this paper (usually Grade 12). */
  gradeId?: string
  /**
   * Optional topic mix tags — grade/chapter origins for planning.
   * Real MCQs live in `questions`.
   */
  chapterSources?: MatricChapterSource[]
}

export type ContentCatalog = {
  grades: ContentGrade[]
  subjects: ContentSubject[]
  chapters: ContentChapter[]
  lessons: ContentLesson[]
  notes: ContentNote[]
  quizzes: ContentQuiz[]
  chapterExams: ContentChapterExam[]
  exams: ContentSubjectExam[]
  flashcardDecks: ContentFlashcardDeck[]
  flashcards: ContentFlashcard[]
}

export type ContentCollection = keyof ContentCatalog

/** Exam timing rule used across mid / final / matric / chapter exams. */
export const MINUTES_PER_QUESTION = 2

export function durationFromQuestionCount(questionCount: number): number {
  const count = Math.max(0, Math.floor(questionCount) || 0)
  return count * MINUTES_PER_QUESTION
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await adminFetch(path, init)
  const data = (await res.json()) as T & { error?: string }
  if (!res.ok) {
    throw new Error(data.error || `Request failed (${res.status})`)
  }
  return data
}

export async function fetchCatalog(): Promise<ContentCatalog> {
  const data = await request<{ catalog: ContentCatalog }>('/api/content')
  return data.catalog
}

export async function upsertContentItem<T extends { id?: string }>(
  collection: ContentCollection,
  item: T,
): Promise<T> {
  const sanitized = sanitizePayloadStrings(item, sanitizeCmsHtml)
  const data = await request<{ item: T }>(`/api/content/${collection}`, {
    method: 'POST',
    body: JSON.stringify(sanitized),
  })
  return data.item
}

function sanitizePayloadStrings<T>(
  value: T,
  sanitize: (html: string) => string,
): T {
  const htmlKeys = new Set([
    'bodyHtml',
    'html',
    'content',
    'body',
    'overview',
    'summary',
    'text',
    'description',
  ])
  if (typeof value === 'string') return value
  if (Array.isArray(value)) {
    return value.map((item) => sanitizePayloadStrings(item, sanitize)) as T
  }
  if (!value || typeof value !== 'object') return value
  const out: Record<string, unknown> = {}
  for (const [key, raw] of Object.entries(value as Record<string, unknown>)) {
    if (typeof raw === 'string' && htmlKeys.has(key)) {
      out[key] = sanitize(raw)
    } else if (raw && typeof raw === 'object') {
      out[key] = sanitizePayloadStrings(raw, sanitize)
    } else {
      out[key] = raw
    }
  }
  return out as T
}

export async function deleteContentItem(
  collection: ContentCollection,
  id: string,
): Promise<void> {
  await request(`/api/content/${collection}/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  })
}

export type UploadedMedia = {
  url: string
  filename: string
  bytes: number
  contentType: string
}

/** Upload image/video/pdf (base64) to the content media store. */
export async function uploadMedia(file: File): Promise<UploadedMedia> {
  const data = await readFileAsDataUrl(file)
  return request<UploadedMedia>('/api/content/upload', {
    method: 'POST',
    body: JSON.stringify({
      filename: file.name,
      contentType: file.type,
      data,
    }),
  })
}

function readFileAsDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result || ''))
    reader.onerror = () => reject(new Error('Could not read file'))
    reader.readAsDataURL(file)
  })
}
