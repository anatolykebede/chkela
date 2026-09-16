import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'

const EMPTY = { items: [] }

export function createFeedbackStore(filePath) {
  ensureFile(filePath)

  function read() {
    try {
      const raw = readFileSync(filePath, 'utf8')
      const parsed = JSON.parse(raw)
      return { items: Array.isArray(parsed.items) ? parsed.items : [] }
    } catch {
      return { items: [] }
    }
  }

  function write(data) {
    writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8')
  }

  function list() {
    return read().items.sort((a, b) => b.createdAt.localeCompare(a.createdAt))
  }

  function create({ message, phone }) {
    const text = String(message || '').trim()
    if (text.length < 8) throw new Error('Feedback must be at least 8 characters')

    const entry = {
      id: `fb_${Date.now().toString(36)}`,
      message: text,
      phone: normalizePhone(phone),
      createdAt: new Date().toISOString(),
      status: 'new',
    }

    const data = read()
    data.items.push(entry)
    write(data)
    return entry
  }

  function setStatus(id, status) {
    const allowed = new Set(['new', 'read', 'archived'])
    if (!allowed.has(status)) throw new Error('Invalid status')

    const data = read()
    const index = data.items.findIndex((item) => item.id === id)
    if (index < 0) throw new Error('Feedback not found')
    data.items[index] = { ...data.items[index], status }
    write(data)
    return data.items[index]
  }

  return { list, create, setStatus }
}

function ensureFile(filePath) {
  const dir = dirname(filePath)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  if (!existsSync(filePath)) {
    writeFileSync(filePath, `${JSON.stringify(EMPTY, null, 2)}\n`, 'utf8')
  }
}

function normalizePhone(value) {
  if (value == null || value === '') return null
  const digits = String(value).replace(/[^\d+]/g, '').trim()
  if (!digits) return null
  return digits.replace(/(?!^)\+/g, '')
}
