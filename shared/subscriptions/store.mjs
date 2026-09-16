import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'

const EMPTY = { subscriptions: [] }

/** Last 9 digits — matches 09… and +2519… forms */
export function phoneKey(value) {
  const digits = String(value || '').replace(/\D/g, '')
  if (digits.length < 9) return null
  return digits.slice(-9)
}

export function normalizePhone(value) {
  const digits = String(value || '').replace(/[^\d+]/g, '').trim()
  if (!digits) return null
  const compact = digits.replace(/(?!^)\+/g, '')
  const onlyDigits = compact.replace(/\D/g, '')
  if (onlyDigits.length < 9 || onlyDigits.length > 13) return null
  if (compact.startsWith('+')) return `+${onlyDigits}`
  if (onlyDigits.startsWith('251') && onlyDigits.length >= 12) {
    return `+${onlyDigits}`
  }
  if (onlyDigits.startsWith('0') && onlyDigits.length === 10) {
    return `+251${onlyDigits.slice(1)}`
  }
  if (onlyDigits.length === 9) return `+251${onlyDigits}`
  return `+${onlyDigits}`
}

export function createSubscriptionsStore(filePath) {
  ensureFile(filePath)

  function read() {
    try {
      const raw = readFileSync(filePath, 'utf8')
      const parsed = JSON.parse(raw)
      return {
        subscriptions: Array.isArray(parsed.subscriptions)
          ? parsed.subscriptions
          : [],
      }
    } catch {
      return { subscriptions: [] }
    }
  }

  function write(data) {
    writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8')
  }

  function list() {
    return read().subscriptions
  }

  function findByPhone(rawPhone) {
    const key = phoneKey(rawPhone)
    if (!key) return null
    return (
      read().subscriptions.find((row) => phoneKey(row.phone) === key) || null
    )
  }

  function isPaid(rawPhone) {
    const row = findByPhone(rawPhone)
    if (!row) return false
    if (row.status && row.status !== 'active') return false
    if (row.expiresAt) {
      const expires = Date.parse(row.expiresAt)
      if (!Number.isNaN(expires) && expires < Date.now()) return false
    }
    return true
  }

  function upsert({ phone, plan = 'plus', status = 'active', expiresAt = null }) {
    const normalized = normalizePhone(phone)
    if (!normalized) throw new Error('phone_required')
    const data = read()
    const key = phoneKey(normalized)
    const index = data.subscriptions.findIndex(
      (row) => phoneKey(row.phone) === key,
    )
    const row = {
      phone: normalized,
      plan: String(plan || 'plus'),
      status: status === 'inactive' || status === 'expired' ? status : 'active',
      expiresAt: expiresAt || null,
      updatedAt: new Date().toISOString(),
    }
    if (index >= 0) {
      data.subscriptions[index] = {
        ...data.subscriptions[index],
        ...row,
      }
      write(data)
      return data.subscriptions[index]
    }
    data.subscriptions.push({
      id: `sub_${Date.now().toString(36)}`,
      createdAt: new Date().toISOString(),
      ...row,
    })
    write(data)
    return data.subscriptions[data.subscriptions.length - 1]
  }

  return { list, findByPhone, isPaid, upsert }
}

function ensureFile(filePath) {
  const dir = dirname(filePath)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  if (!existsSync(filePath)) {
    writeFileSync(filePath, `${JSON.stringify(EMPTY, null, 2)}\n`, 'utf8')
  }
}
