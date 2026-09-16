/** @typedef {'natural' | 'social' | null} GradeStream */
/** @typedef {'draft' | 'published'} PublishStatus */
/** @typedef {'mid' | 'final' | 'matric'} SubjectExamType */

/**
 * @typedef {Object} ContentGrade
 * @property {string} id
 * @property {string} label
 * @property {GradeStream} stream
 */

/**
 * @typedef {Object} ContentSubject
 * @property {string} id
 * @property {string} name
 * @property {string} gradeId
 * @property {boolean} locked
 */

/**
 * @typedef {Object} ContentChapter
 * @property {string} id
 * @property {string} subjectId
 * @property {string} title
 * @property {string} subtitle
 * @property {number} order
 */

/**
 * @typedef {Object} ContentLesson
 * @property {string} id
 * @property {string} chapterId
 * @property {string} title
 * @property {number} [order]
 * @property {number} durationMinutes
 * @property {PublishStatus} status
 * @property {string} updatedAt
 */

/**
 * @typedef {Object} ContentNote
 * @property {string} id
 * @property {string} chapterId
 * @property {string} lessonId Lesson this note belongs to (required for new notes)
 * @property {string} title
 * @property {string} bodyHtml
 * @property {PublishStatus} status
 * @property {string} updatedAt
 */

/**
 * @typedef {Object} ContentQuestion
 * @property {string} id
 * @property {string} prompt
 * @property {string[]} options
 * @property {number} correctIndex
 * @property {string} explanation
 * @property {string} [gradeId]
 * @property {string} [subjectId]
 * @property {string} [chapterId]
 */

/**
 * @typedef {Object} ContentQuiz
 * @property {string} id
 * @property {string} chapterId
 * @property {string|null} noteId
 * @property {string} title
 * @property {number} questionCount
 * @property {ContentQuestion[]} [questions]
 * @property {PublishStatus} status
 * @property {string} updatedAt
 */

/**
 * @typedef {Object} ContentChapterExam
 * @property {string} id
 * @property {string} chapterId
 * @property {string} title
 * @property {number} questionCount
 * @property {number} durationMinutes
 * @property {ContentQuestion[]} [questions]
 * @property {PublishStatus} status
 * @property {string} updatedAt
 */

/**
 * @typedef {Object} MatricChapterSource
 * @property {string} gradeId
 * @property {string} subjectId
 * @property {string} chapterId
 * @property {number} questionCount
 */

/**
 * @typedef {Object} ContentSubjectExam
 * @property {string} id
 * @property {string} subjectId
 * @property {SubjectExamType} type
 * @property {string} title
 * @property {string} subtitle
 * @property {number} questionCount
 * @property {number} durationMinutes
 * @property {PublishStatus} status
 * @property {string} updatedAt
 * @property {ContentQuestion[]} [questions] Multiple-choice items for this paper
 * @property {number} [year]
 * @property {string} [gradeId] Sitting grade (who takes the paper)
 * @property {MatricChapterSource[]} [chapterSources] Optional topic-mix tags by grade/chapter
 */

/**
 * @typedef {Object} ContentCatalog
 * @property {ContentGrade[]} grades
 * @property {ContentSubject[]} subjects
 * @property {ContentChapter[]} chapters
 * @property {ContentLesson[]} lessons
 * @property {ContentNote[]} notes
 * @property {ContentQuiz[]} quizzes
 * @property {ContentChapterExam[]} chapterExams
 * @property {ContentSubjectExam[]} exams
 * @property {ContentFlashcardDeck[]} [flashcardDecks]
 * @property {ContentFlashcard[]} [flashcards]
 */

export {}
