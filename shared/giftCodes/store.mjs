import { randomBytes } from 'node:crypto'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'

const EMPTY = { codes: [] }

export function createGiftCodeStore(filePath) {
  ensureFile(filePath)

  function read() {
    try {
      const raw = readFileSync(filePath, 'utf8')
      const parsed = JSON.parse(raw)
      return { codes: Array.isArray(parsed.codes) ? parsed.codes : [] }
    } catch {
      return { codes: [] }
    }
  }

  function write(data) {
    writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8')
  }

  function list() {
    return read().codes.sort((a, b) => b.createdAt.localeCompare(a.createdAt))
  }

  function create(amountBirr) {
    const amount = Math.round(Number(amountBirr))
    if (!Number.isFinite(amount) || amount < 1) {
      throw new Error('Amount must be at least 1 Birr')
    }

    const entry = {
      id: `g_${Date.now().toString(36)}`,
      code: generateCode(),
      amountBirr: amount,
      createdAt: new Date().toISOString(),
      claimedAt: null,
      claimedBy: null,
    }

    const data = read()
    data.codes.push(entry)
    write(data)
    return entry
  }

  function claim(rawCode, rawPhone, studentsStore) {
    const code = normalizeCode(rawCode)
    if (!code) return { ok: false, error: 'invalid' }

    const phone = normalizePhone(rawPhone)
    if (!phone) return { ok: false, error: 'missing_phone' }

    if (studentsStore) {
      const student = studentsStore.findActiveByPhone(phone)
      if (!student) return { ok: false, error: 'not_a_student' }
    }

    const data = read()
    const index = data.codes.findIndex((item) => item.code === code)
    if (index < 0) return { ok: false, error: 'not_found' }

    const entry = data.codes[index]
    if (entry.claimedAt) return { ok: false, error: 'already_claimed' }

    entry.claimedAt = new Date().toISOString()
    entry.claimedBy = phone
    data.codes[index] = entry
    write(data)

    return { ok: true, amountBirr: entry.amountBirr, code: entry.code }
  }

  return { list, create, claim }
}

function ensureFile(filePath) {
  const dir = dirname(filePath)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  if (!existsSync(filePath)) {
    writeFileSync(filePath, `${JSON.stringify(EMPTY, null, 2)}\n`, 'utf8')
  }
}

function generateCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  const bytes = randomBytes(8)
  let out = 'CHK-'
  for (let i = 0; i < 8; i += 1) {
    out += alphabet[bytes[i] % alphabet.length]
    if (i === 3) out += '-'
  }
  return out
}

function normalizeCode(value) {
  return String(value || '')
    .trim()
    .toUpperCase()
    .replace(/\s+/g, '')
    .replace(/[^A-Z0-9-]/g, '')
}

function normalizePhone(value) {
  const digits = String(value || '').replace(/[^\d+]/g, '').trim()
  if (!digits) return null
  const compact = digits.replace(/(?!^)\+/g, '')
  const onlyDigits = compact.replace(/\D/g, '')
  // Ethiopian mobiles are typically 9–12 digits (+2519… or 09…)
  if (onlyDigits.length < 9 || onlyDigits.length > 13) return null
  return compact
}
