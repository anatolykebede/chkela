import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from 'node:fs'
import { dirname } from 'node:path'

const EMPTY = { progress: [] }

export function createPathProgressStore(filePath) {
  ensureFile(filePath)

  /** Serializes read-modify-write so concurrent POSTs do not clobber. */
  let writeChain = Promise.resolve()

  function read() {
    try {
      const raw = readFileSync(filePath, 'utf8')
      const parsed = JSON.parse(raw)
      return {
        progress: Array.isArray(parsed.progress) ? parsed.progress : [],
      }
    } catch {
      return { progress: [] }
    }
  }

  function write(data) {
    const dir = dirname(filePath)
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
    const tmp = `${filePath}.${process.pid}.${Date.now()}.tmp`
    writeFileSync(tmp, `${JSON.stringify(data, null, 2)}\n`, 'utf8')
    renameSync(tmp, filePath)
  }

  function list() {
    return read().progress.sort((a, b) =>
      String(b.updatedAt || '').localeCompare(String(a.updatedAt || '')),
    )
  }

  function findByPhone(rawPhone) {
    const key = phoneKey(rawPhone)
    if (!key) return null
    return (
      read().progress.find((row) => phoneKey(row.phone) === key) || null
    )
  }

  function upsert(body) {
    const phone = normalizePhone(body.phone)
    if (!phone) throw new Error('phone is required')

    const run = writeChain.then(() => {
      const data = read()
      const key = phoneKey(phone)
      const index = data.progress.findIndex((row) => phoneKey(row.phone) === key)
      const prev = index >= 0 ? data.progress[index] : null
      const now = new Date().toISOString()

      const mergedStars = mergeIntMaps(prev?.stars, body.stars)
      const mergedWeak = mergeIntMaps(prev?.weakSkills, body.weakSkills)
      const next = {
        phone,
        currentLevelId: String(
          body.currentLevelId || prev?.currentLevelId || '',
        ),
        currentLevelNumber:
          Number(body.currentLevelNumber) ||
          Number(prev?.currentLevelNumber) ||
          0,
        currentLevelTitle: String(
          body.currentLevelTitle || prev?.currentLevelTitle || '',
        ),
        clearedCount: Math.max(
          Number(body.clearedCount) || 0,
          Number(prev?.clearedCount) || 0,
          Object.values(mergedStars).filter((n) => n >= 1).length,
        ),
        totalStars: Math.max(
          Number(body.totalStars) || 0,
          Number(prev?.totalStars) || 0,
          Object.values(mergedStars).reduce((s, n) => s + (Number(n) || 0), 0),
        ),
        streak: Math.max(Number(body.streak) || 0, Number(prev?.streak) || 0),
        xp: Math.max(Number(body.xp) || 0, Number(prev?.xp) || 0),
        stars: mergedStars,
        weakSkills: mergedWeak,
        dailyDoneDay: pickDailyDay(body.dailyDoneDay, prev?.dailyDoneDay),
        updatedAt: now,
      }

      if (index >= 0) {
        data.progress[index] = {
          ...data.progress[index],
          ...next,
          id: data.progress[index].id,
        }
      } else {
        data.progress.push({ id: `pp_${Date.now().toString(36)}`, ...next })
      }
      write(data)
      return findByPhone(phone)
    })

    writeChain = run.then(
      () => undefined,
      () => undefined,
    )
    return run
  }

  return { list, findByPhone, upsert }
}

function mergeIntMaps(prev, incoming) {
  const out = {}
  if (prev && typeof prev === 'object') {
    for (const [k, v] of Object.entries(prev)) {
      const n = Number(v)
      if (Number.isFinite(n)) out[k] = n
    }
  }
  if (incoming && typeof incoming === 'object') {
    for (const [k, v] of Object.entries(incoming)) {
      const n = Number(v)
      if (!Number.isFinite(n)) continue
      out[k] = Math.max(out[k] || 0, n)
    }
  }
  return out
}

function pickDailyDay(incoming, prev) {
  const a = incoming ? String(incoming) : null
  const b = prev ? String(prev) : null
  if (!a) return b
  if (!b) return a
  return a >= b ? a : b
}

function ensureFile(filePath) {
  const dir = dirname(filePath)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  if (!existsSync(filePath)) {
    writeFileSync(filePath, `${JSON.stringify(EMPTY, null, 2)}\n`, 'utf8')
  }
}

function normalizePhone(value) {
  const digits = String(value || '').replace(/[^\d+]/g, '').trim()
  if (!digits) return null
  return digits.replace(/(?!^)\+/g, '')
}

function phoneKey(value) {
  return String(value || '').replace(/\D/g, '')
}
