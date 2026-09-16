import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { pool } from '../db.mjs'
import { phoneKey, isPaid } from './subscriptions.mjs'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(__dirname, '../../../')

function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'))
  } catch {
    return fallback
  }
}

function uniquePhones(phones) {
  const seen = new Set()
  const out = []
  for (const phone of phones) {
    const key = phoneKey(phone)
    if (!key || seen.has(key)) continue
    seen.add(key)
    out.push(phone)
  }
  return out
}

function phonesFromTokens(tokens) {
  return uniquePhones(tokens.map((t) => t.phone).filter(Boolean))
}

async function listTokens() {
  const r = await pool.query('SELECT token, phone, platform FROM device_tokens ORDER BY updated_at DESC')
  return r.rows
}

function studentKeys(status) {
  const studentsFile = path.join(root, 'shared/students/data.json')
  const raw = readJson(studentsFile, { students: [] })
  const keys = new Set()
  for (const student of raw.students || []) {
    if (status && student.status !== status) continue
    const key = phoneKey(student.phone)
    if (key) keys.add(key)
  }
  return keys
}

function giftClaimerKeys() {
  const codesFile = path.join(root, 'shared/giftCodes/data.json')
  const raw = readJson(codesFile, { codes: [] })
  const keys = new Set()
  for (const code of raw.codes || []) {
    if (!code.claimedAt || !code.claimedBy) continue
    const key = phoneKey(code.claimedBy)
    if (key) keys.add(key)
  }
  return keys
}

async function mapProfileKeys() {
  const r = await pool.query('SELECT phone FROM profiles')
  const keys = new Set()
  for (const row of r.rows) {
    const key = phoneKey(row.phone)
    if (key) keys.add(key)
  }
  return keys
}

const definitions = [
  { id: 'all', label: 'All registered devices', description: 'Every phone that opened Chkela and allowed notifications (FCM token)' },
  { id: 'unpaid', label: 'Unpaid / free users', description: 'Devices with no active paid subscription' },
  { id: 'paid', label: 'Paid subscribers', description: 'Devices with an active subscription on file' },
  { id: 'ios', label: 'iOS devices', description: 'Registered Apple devices only' },
  { id: 'android', label: 'Android devices', description: 'Registered Android devices only' },
  { id: 'active_students', label: 'Active allowlisted students', description: 'Active students who also have the app installed' },
  { id: 'inactive_students', label: 'Inactive students', description: 'Inactive students who still have a device token' },
  { id: 'map_profiles', label: 'Map profile users', description: 'People who completed a map profile' },
  { id: 'gift_claimers', label: 'Gift code claimers', description: 'Users who claimed a gift code' },
  { id: 'never_gift', label: 'Never claimed a gift', description: 'Active students with devices who never claimed' },
]

export async function resolveAudience(audienceId) {
  const id = String(audienceId || 'all').trim() || 'all'
  const tokens = await listTokens()
  const activeKeys = studentKeys('active')
  const inactiveKeys = studentKeys('inactive')
  const claimers = giftClaimerKeys()
  const mapKeys = await mapProfileKeys()
  let matched = tokens

  if (id === 'unpaid') {
    const keep = []
    for (const t of tokens) {
      if (t.phone && !(await isPaid(t.phone))) keep.push(t)
    }
    matched = keep
  } else if (id === 'paid') {
    const keep = []
    for (const t of tokens) {
      if (t.phone && (await isPaid(t.phone))) keep.push(t)
    }
    matched = keep
  } else if (id === 'ios') {
    matched = tokens.filter((t) => String(t.platform || '').toLowerCase() === 'ios')
  } else if (id === 'android') {
    matched = tokens.filter((t) => String(t.platform || '').toLowerCase() === 'android')
  } else if (id === 'active_students') {
    matched = tokens.filter((t) => t.phone && activeKeys.has(phoneKey(t.phone)))
  } else if (id === 'inactive_students') {
    matched = tokens.filter((t) => t.phone && inactiveKeys.has(phoneKey(t.phone)))
  } else if (id === 'map_profiles') {
    matched = tokens.filter((t) => t.phone && mapKeys.has(phoneKey(t.phone)))
  } else if (id === 'gift_claimers') {
    matched = tokens.filter((t) => t.phone && claimers.has(phoneKey(t.phone)))
  } else if (id === 'never_gift') {
    matched = tokens.filter((t) => {
      if (!t.phone) return false
      const key = phoneKey(t.phone)
      return activeKeys.has(key) && !claimers.has(key)
    })
  } else if (id !== 'all') {
    throw new Error(`Unknown audience: ${id}`)
  }

  return {
    id,
    deviceCount: matched.length,
    phones: phonesFromTokens(matched),
    tokens: matched.map((t) => t.token),
  }
}

export async function listAudiencesWithCounts() {
  const out = []
  for (const def of definitions) {
    try {
      const resolved = await resolveAudience(def.id)
      out.push({ ...def, deviceCount: resolved.deviceCount, phoneCount: resolved.phones.length })
    } catch {
      out.push({ ...def, deviceCount: 0, phoneCount: 0 })
    }
  }
  return out
}

