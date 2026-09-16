import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'

const EMPTY = { students: [] }

export function createStudentsStore(filePath) {
  ensureFile(filePath)

  function read() {
    try {
      const raw = readFileSync(filePath, 'utf8')
      const parsed = JSON.parse(raw)
      return { students: Array.isArray(parsed.students) ? parsed.students : [] }
    } catch {
      return { students: [] }
    }
  }

  function write(data) {
    writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8')
  }

  function list() {
    return read().students.sort((a, b) => a.name.localeCompare(b.name))
  }

  function findActiveByPhone(rawPhone) {
    const key = phoneKey(rawPhone)
    if (!key) return null
    return (
      read().students.find(
        (student) =>
          student.status === 'active' && phoneKey(student.phone) === key,
      ) || null
    )
  }

  function upsert({ name, phone, status = 'active' }) {
    const normalized = normalizePhone(phone)
    if (!normalized) throw new Error('Enter a valid phone number')
    const trimmedName = String(name || '').trim()
    if (!trimmedName) throw new Error('Enter a student name')

    const data = read()
    const key = phoneKey(normalized)
    const existingIndex = data.students.findIndex(
      (student) => phoneKey(student.phone) === key,
    )

    if (existingIndex >= 0) {
      data.students[existingIndex] = {
        ...data.students[existingIndex],
        name: trimmedName,
        phone: normalized,
        status: status === 'inactive' ? 'inactive' : 'active',
      }
      write(data)
      return data.students[existingIndex]
    }

    const student = {
      id: `s_${Date.now().toString(36)}`,
      name: trimmedName,
      phone: normalized,
      status: status === 'inactive' ? 'inactive' : 'active',
    }
    data.students.push(student)
    write(data)
    return student
  }

  return { list, findActiveByPhone, upsert }
}

export function normalizePhone(value) {
  const digits = String(value || '').replace(/[^\d+]/g, '').trim()
  if (!digits) return null
  const compact = digits.replace(/(?!^)\+/g, '')
  const onlyDigits = compact.replace(/\D/g, '')
  if (onlyDigits.length < 9 || onlyDigits.length > 13) return null
  return compact
}

/** Last 9 digits — matches 09… and +2519… forms */
export function phoneKey(value) {
  const normalized = normalizePhone(value)
  if (!normalized) return null
  const onlyDigits = normalized.replace(/\D/g, '')
  return onlyDigits.slice(-9)
}

function ensureFile(filePath) {
  const dir = dirname(filePath)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  if (!existsSync(filePath)) {
    writeFileSync(filePath, `${JSON.stringify(EMPTY, null, 2)}\n`, 'utf8')
  }
}
