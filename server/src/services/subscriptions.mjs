import { randomUUID } from 'node:crypto'
import { pool } from '../db.mjs'
import { normalizePhone } from './friends.mjs'

export function phoneKey(value) {
  const digits = String(value || '').replace(/\D/g, '')
  if (digits.length < 9) return null
  return digits.slice(-9)
}

/** Paid entitlements — G11/G12 Natural and Social are separate. */
export const ALL_GRADE_ENTITLEMENTS = [
  'Grade 9',
  'Grade 10',
  'Grade 11 · Natural',
  'Grade 11 · Social',
  'Grade 12 · Natural',
  'Grade 12 · Social',
]

export function normalizeGradeLabel(value) {
  const raw = String(value || '')
    .trim()
    .replace(/\s+/g, ' ')
    .replace(/\s*[·•|-]\s*/g, ' · ')
  if (!raw) return null

  const lower = raw.toLowerCase()
  if (lower.startsWith('grade 9')) return 'Grade 9'
  if (lower.startsWith('grade 10')) return 'Grade 10'

  const is11 = lower.startsWith('grade 11')
  const is12 = lower.startsWith('grade 12')
  if (!is11 && !is12) return raw

  const base = is11 ? 'Grade 11' : 'Grade 12'
  if (/\bnatural\b/i.test(raw)) return `${base} · Natural`
  if (/\bsocial\b/i.test(raw)) return `${base} · Social`
  // Bare Grade 11 / 12 is not a valid entitlement (streams are separate).
  return null
}

export function normalizeGradesList(grades, { plan } = {}) {
  const planKey = String(plan || '').toLowerCase()
  if (planKey === 'bundle' || planKey === 'all') {
    return [...ALL_GRADE_ENTITLEMENTS]
  }
  const out = []
  const seen = new Set()
  for (const item of Array.isArray(grades) ? grades : []) {
    const key = normalizeGradeLabel(item)
    if (!key || seen.has(key)) continue
    seen.add(key)
    out.push(key)
  }
  return out
}

function parseGrades(value) {
  if (Array.isArray(value)) return normalizeGradesList(value)
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value)
      if (Array.isArray(parsed)) return normalizeGradesList(parsed)
    } catch {
      // ignore
    }
  }
  return []
}

function rowToJson(row) {
  const grades = parseGrades(row.grades)
  return {
    id: row.id,
    phone: row.phone,
    plan: row.plan,
    status: row.status,
    grades,
    expiresAt: row.expires_at?.toISOString?.() || null,
    createdAt: row.created_at?.toISOString?.() || null,
    updatedAt: row.updated_at?.toISOString?.() || null,
  }
}

function mergeGrades(existing, incoming) {
  return normalizeGradesList([...(existing || []), ...(incoming || [])])
}

function laterExpires(a, b) {
  if (!a) return b || null
  if (!b) return a
  return Date.parse(a) >= Date.parse(b) ? a : b
}

export async function listSubscriptions() {
  const r = await pool.query('SELECT * FROM subscriptions ORDER BY updated_at DESC')
  return r.rows.map(rowToJson)
}

export async function findSubscriptionByPhone(rawPhone) {
  const key = phoneKey(rawPhone)
  if (!key) return null
  const r = await pool.query('SELECT * FROM subscriptions ORDER BY updated_at DESC')
  const row = r.rows.find((x) => phoneKey(x.phone) === key)
  return row ? rowToJson(row) : null
}

export async function isPaid(rawPhone) {
  const row = await findSubscriptionByPhone(rawPhone)
  if (!row) return false
  if (row.status && row.status !== 'active') return false
  if (row.expiresAt) {
    const expires = Date.parse(row.expiresAt)
    if (!Number.isNaN(expires) && expires < Date.now()) return false
  }
  return true
}

export async function isPaidForGrade(rawPhone, grade) {
  if (!(await isPaid(rawPhone))) return false
  const row = await findSubscriptionByPhone(rawPhone)
  if (!row) return false
  const planKey = String(row.plan || '').toLowerCase()
  if (planKey === 'bundle' || planKey === 'all') return true
  const grades = row.grades || []
  if (!grades.length) return false
  const wanted = normalizeGradeLabel(grade)
  if (!wanted) return false
  return grades.some((g) => normalizeGradeLabel(g) === wanted)
}

export async function upsertSubscription({
  phone,
  plan = 'plus',
  status = 'active',
  expiresAt = null,
  grades = [],
  mergeGradesWithExisting = true,
}) {
  const normalized = normalizePhone(phone)
  if (!normalized) throw new Error('phone_required')

  const existing = await findSubscriptionByPhone(normalized)
  let nextGrades = normalizeGradesList(grades, { plan })
  if (mergeGradesWithExisting && existing?.grades?.length) {
    nextGrades = mergeGrades(existing.grades, nextGrades)
  }
  if (!nextGrades.length && String(plan).toLowerCase() === 'bundle') {
    nextGrades = [...ALL_GRADE_ENTITLEMENTS]
  }

  const coversAll =
    ALL_GRADE_ENTITLEMENTS.every((g) => nextGrades.includes(g)) ||
    String(plan).toLowerCase() === 'bundle'
  const nextPlan = coversAll ? 'bundle' : String(plan || 'grades' || 'plus')
  const nextExpires = mergeGradesWithExisting
    ? laterExpires(existing?.expiresAt, expiresAt)
    : expiresAt
      ? new Date(expiresAt).toISOString()
      : null

  const payload = {
    phone: normalized,
    plan: nextPlan,
    status: status === 'inactive' || status === 'expired' ? status : 'active',
    expiresAt: nextExpires ? new Date(nextExpires).toISOString() : null,
    grades: nextGrades,
  }
  const id = `sub_${randomUUID().slice(0, 12)}`
  const u = await pool.query(
    `INSERT INTO subscriptions (id, phone, plan, status, expires_at, grades, created_at, updated_at)
     VALUES ($1,$2,$3,$4,$5,$6::jsonb,NOW(),NOW())
     ON CONFLICT (phone) DO UPDATE SET
       plan = EXCLUDED.plan,
       status = EXCLUDED.status,
       expires_at = EXCLUDED.expires_at,
       grades = EXCLUDED.grades,
       updated_at = NOW()
     RETURNING *`,
    [
      id,
      payload.phone,
      payload.plan,
      payload.status,
      payload.expiresAt,
      JSON.stringify(payload.grades),
    ],
  )
  return rowToJson(u.rows[0])
}
