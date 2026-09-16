import fs from 'node:fs'
import path from 'node:path'
import { randomUUID } from 'node:crypto'

const COLLECTIONS = [
  'grades',
  'subjects',
  'chapters',
  'lessons',
  'notes',
  'quizzes',
  'chapterExams',
  'exams',
  'flashcardDecks',
  'flashcards',
]

function emptyCatalog() {
  return {
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
}

export function createContentStore(filePath, { assetsFile, assetsFiguresDir } = {}) {
  const resolved = path.resolve(filePath)

  function read() {
    if (!fs.existsSync(resolved)) {
      const empty = emptyCatalog()
      write(empty)
      return empty
    }
    const raw = fs.readFileSync(resolved, 'utf8')
    const data = JSON.parse(raw)
    for (const key of COLLECTIONS) {
      if (!Array.isArray(data[key])) data[key] = []
    }
    return data
  }

  function write(data) {
    fs.mkdirSync(path.dirname(resolved), { recursive: true })
    const text = `${JSON.stringify(data, null, 2)}\n`
    fs.writeFileSync(resolved, text, 'utf8')
    if (assetsFile) {
      const assetsPath = path.resolve(assetsFile)
      fs.mkdirSync(path.dirname(assetsPath), { recursive: true })
      fs.writeFileSync(assetsPath, text, 'utf8')
    }
    if (assetsFiguresDir) {
      const srcFigures = path.join(path.dirname(resolved), 'figures')
      const destFigures = path.resolve(assetsFiguresDir)
      if (fs.existsSync(srcFigures)) {
        fs.mkdirSync(destFigures, { recursive: true })
        fs.cpSync(srcFigures, destFigures, { recursive: true })
      }
    }
  }

  function list() {
    return read()
  }

  function upsert(collection, item) {
    if (!COLLECTIONS.includes(collection)) {
      throw new Error(`Unknown collection: ${collection}`)
    }
    const data = read()
    const listItems = data[collection]
    const id = item.id || `${collection.slice(0, 3)}-${randomUUID().slice(0, 8)}`
    const now = new Date().toISOString().slice(0, 10)
    const next = {
      ...item,
      id,
      updatedAt: item.updatedAt || now,
    }
    const index = listItems.findIndex((row) => row.id === id)
    if (index >= 0) {
      listItems[index] = { ...listItems[index], ...next }
    } else {
      listItems.push(next)
    }
    write(data)
    return listItems.find((row) => row.id === id)
  }

  function remove(collection, id) {
    if (!COLLECTIONS.includes(collection)) {
      throw new Error(`Unknown collection: ${collection}`)
    }
    const data = read()
    const before = data[collection].length
    data[collection] = data[collection].filter((row) => row.id !== id)

    // Cascade deletes for chapter-scoped content
    if (collection === 'chapters') {
      const deckIds = (data.flashcardDecks || [])
        .filter((d) => d.chapterId === id)
        .map((d) => d.id)
      for (const child of [
        'lessons',
        'notes',
        'quizzes',
        'chapterExams',
        'flashcardDecks',
        'flashcards',
      ]) {
        data[child] = data[child].filter((row) => row.chapterId !== id)
      }
      data.flashcards = data.flashcards.filter(
        (row) => !deckIds.includes(row.deckId),
      )
    }
    if (collection === 'flashcardDecks') {
      data.flashcards = data.flashcards.filter((row) => row.deckId !== id)
    }
    if (collection === 'subjects') {
      const chapterIds = data.chapters
        .filter((c) => c.subjectId === id)
        .map((c) => c.id)
      data.chapters = data.chapters.filter((c) => c.subjectId !== id)
      data.exams = data.exams.filter((e) => e.subjectId !== id)
      for (const child of [
        'lessons',
        'notes',
        'quizzes',
        'chapterExams',
        'flashcardDecks',
        'flashcards',
      ]) {
        data[child] = data[child].filter((row) => !chapterIds.includes(row.chapterId))
      }
    }
    if (collection === 'grades') {
      const subjectIds = data.subjects
        .filter((s) => s.gradeId === id)
        .map((s) => s.id)
      const chapterIds = data.chapters
        .filter((c) => subjectIds.includes(c.subjectId))
        .map((c) => c.id)
      data.subjects = data.subjects.filter((s) => s.gradeId !== id)
      data.chapters = data.chapters.filter((c) => !subjectIds.includes(c.subjectId))
      data.exams = data.exams.filter((e) => !subjectIds.includes(e.subjectId))
      for (const child of [
        'lessons',
        'notes',
        'quizzes',
        'chapterExams',
        'flashcardDecks',
        'flashcards',
      ]) {
        data[child] = data[child].filter((row) => !chapterIds.includes(row.chapterId))
      }
    }

    write(data)
    return before !== data[collection].length
  }

  return { list, upsert, remove, collections: COLLECTIONS }
}
