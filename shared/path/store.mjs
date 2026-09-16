import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'
import { randomUUID } from 'node:crypto'

const COLLECTIONS = ['levels', 'challenges']

function emptyCatalog() {
  return { levels: [], challenges: [] }
}

export function createPathStore(filePath, { assetsFile } = {}) {
  ensureFile(filePath)

  function read() {
    try {
      const raw = readFileSync(filePath, 'utf8')
      const parsed = JSON.parse(raw)
      const data = emptyCatalog()
      for (const key of COLLECTIONS) {
        data[key] = Array.isArray(parsed[key]) ? parsed[key] : []
      }
      return data
    } catch {
      return emptyCatalog()
    }
  }

  function write(data) {
    const dir = dirname(filePath)
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
    const text = `${JSON.stringify(data, null, 2)}\n`
    writeFileSync(filePath, text, 'utf8')
    if (assetsFile) {
      const assetsDir = dirname(assetsFile)
      if (!existsSync(assetsDir)) mkdirSync(assetsDir, { recursive: true })
      writeFileSync(assetsFile, text, 'utf8')
    }
  }

  function list() {
    const data = read()
    data.levels = [...data.levels].sort((a, b) => {
      const gradeOrder = { 'grade-9': 9, 'grade-10': 10, 'grade-11': 11, 'grade-12': 12 }
      const ga = gradeOrder[a.gradeId] || 9
      const gb = gradeOrder[b.gradeId] || 9
      if (ga !== gb) return ga - gb
      return (a.number || 0) - (b.number || 0)
    })
    data.challenges = [...data.challenges].sort((a, b) => {
      if (a.levelId !== b.levelId) {
        return String(a.levelId).localeCompare(String(b.levelId))
      }
      return (a.order || 0) - (b.order || 0)
    })
    return data
  }

  function upsert(collection, item) {
    if (!COLLECTIONS.includes(collection)) {
      throw new Error(`Unknown collection: ${collection}`)
    }
    const data = read()
    const rows = data[collection]
    const id = item.id || `${collection.slice(0, 3)}-${randomUUID().slice(0, 8)}`
    const now = new Date().toISOString()
    const next = {
      ...item,
      id,
      updatedAt: now,
    }

    if (collection === 'levels') {
      next.number = Number(next.number) || 1
      next.xpReward = Number(next.xpReward) || 25
      next.kind = ['standard', 'checkpoint', 'boss'].includes(next.kind)
        ? next.kind
        : 'standard'
      next.status = next.status === 'draft' ? 'draft' : 'published'
      next.title = String(next.title || 'Untitled gate').trim()
      next.subject = String(next.subject || 'Biology').trim()
      next.gradeId = ['grade-9', 'grade-10', 'grade-11', 'grade-12'].includes(
        next.gradeId,
      )
        ? next.gradeId
        : 'grade-9'
      next.competency = String(next.competency || '').trim()
      next.skillTag = String(next.skillTag || 'practice').trim()
      next.hook = String(next.hook || '').trim()
    }

    if (collection === 'challenges') {
      next.levelId = String(next.levelId || '').trim()
      if (!next.levelId) throw new Error('Challenge needs a levelId')
      next.type = ['strike', 'blitz', 'link', 'sequence', 'answer'].includes(
        next.type,
      )
        ? next.type
        : 'strike'
      next.order = Number(next.order) || 1
      next.skillTag = String(next.skillTag || 'practice').trim()
      next.waveLabel = String(
        next.waveLabel || next.type.toUpperCase(),
      ).trim()
      next.status = next.status === 'draft' ? 'draft' : 'published'
      normalizeChallengeFields(next)
    }

    const index = rows.findIndex((row) => row.id === id)
    if (index >= 0) {
      rows[index] = { ...rows[index], ...next }
    } else {
      rows.push(next)
    }
    write(data)
    return rows.find((row) => row.id === id)
  }

  function remove(collection, id) {
    if (!COLLECTIONS.includes(collection)) {
      throw new Error(`Unknown collection: ${collection}`)
    }
    const data = read()
    data[collection] = data[collection].filter((row) => row.id !== id)
    if (collection === 'levels') {
      data.challenges = data.challenges.filter((row) => row.levelId !== id)
    }
    write(data)
    return true
  }

  return { list, upsert, remove }
}

function normalizeChallengeFields(next) {
  if (next.type === 'strike') {
    next.prompt = String(next.prompt || '').trim()
    next.options = Array.isArray(next.options)
      ? next.options.map((o) => String(o))
      : ['', '', '', '']
    next.correctIndex = Number(next.correctIndex) || 0
  }
  if (next.type === 'blitz') {
    next.prompt = String(next.prompt || '').trim()
    next.isTrue = Boolean(next.isTrue)
    next.seconds = Math.max(3, Number(next.seconds) || 8)
  }
  if (next.type === 'link') {
    if (Array.isArray(next.pairs)) {
      const map = {}
      for (const pair of next.pairs) {
        if (pair?.left && pair?.right) map[String(pair.left)] = String(pair.right)
      }
      next.pairs = map
    } else if (next.pairs && typeof next.pairs === 'object') {
      next.pairs = { ...next.pairs }
    } else {
      next.pairs = {}
    }
  }
  if (next.type === 'sequence') {
    next.title = String(next.title || 'Order the steps').trim()
    next.stepsInOrder = Array.isArray(next.stepsInOrder)
      ? next.stepsInOrder.map((s) => String(s)).filter(Boolean)
      : []
  }
  if (next.type === 'answer') {
    next.prompt = String(next.prompt || '').trim()
    next.correctAnswer = String(next.correctAnswer || '').trim()
    next.acceptedAnswers = Array.isArray(next.acceptedAnswers)
      ? next.acceptedAnswers.map((a) => String(a).trim()).filter(Boolean)
      : []
    next.hint = next.hint ? String(next.hint).trim() : ''
    next.inputKind = ['any', 'number', 'text'].includes(next.inputKind)
      ? next.inputKind
      : 'any'
  }
}

function ensureFile(filePath) {
  const dir = dirname(filePath)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  if (!existsSync(filePath)) {
    writeFileSync(filePath, `${JSON.stringify(emptyCatalog(), null, 2)}\n`, 'utf8')
  }
}
