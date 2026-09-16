import fs from 'node:fs'
import path from 'node:path'
import { randomUUID } from 'node:crypto'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'
import { pool } from '../db.mjs'
import { normalizePhone } from './friends.mjs'
import { phoneKey } from './subscriptions.mjs'

const require = createRequire(
  path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../dashboard/package.json'),
)

let messaging = null
let initError = null

function getMessaging() {
  if (messaging) return messaging
  if (initError) return null
  const accountFile =
    process.env.FCM_SERVICE_ACCOUNT_PATH ||
    path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../shared/notifications/serviceAccount.json')
  if (!fs.existsSync(accountFile)) {
    initError = 'No serviceAccount.json'
    return null
  }
  try {
    const { initializeApp, getApps, cert } = require('firebase-admin/app')
    const { getMessaging: getFcm } = require('firebase-admin/messaging')
    if (!getApps().length) {
      const serviceAccount = JSON.parse(fs.readFileSync(accountFile, 'utf8'))
      initializeApp({ credential: cert(serviceAccount) })
    }
    messaging = getFcm()
    return messaging
  } catch (error) {
    initError = error instanceof Error ? error.message : 'FCM admin init failed'
    return null
  }
}

export async function registerToken({ token, phone, platform }) {
  const cleanToken = String(token || '').trim()
  if (!cleanToken) throw new Error('Token is required')
  const cleanPhone = normalizePhone(phone) || String(phone || '').trim()
  if (!cleanPhone) throw new Error('Phone is required')
  const row = await pool.query(
    `INSERT INTO device_tokens (token, phone, platform, updated_at)
     VALUES ($1,$2,$3,NOW())
     ON CONFLICT (token) DO UPDATE SET phone=EXCLUDED.phone, platform=EXCLUDED.platform, updated_at=NOW()
     RETURNING token, phone, platform, updated_at`,
    [cleanToken, cleanPhone, String(platform || 'unknown').trim() || 'unknown'],
  )
  const t = row.rows[0]
  return {
    token: t.token,
    phone: t.phone,
    platform: t.platform,
    updatedAt: t.updated_at?.toISOString?.() || String(t.updated_at || ''),
  }
}

export async function status() {
  const count = await pool.query('SELECT COUNT(*)::int AS c FROM device_tokens')
  return {
    fcmReady: Boolean(getMessaging()),
    tokenCount: Number(count.rows[0]?.c || 0),
    ready: Boolean(getMessaging()),
    registeredTokens: Number(count.rows[0]?.c || 0),
    error: initError,
  }
}

async function tokensForPhones(rawPhones) {
  const keys = []
  const exact = []
  for (const raw of rawPhones) {
    const normalized = normalizePhone(raw)
    const key = phoneKey(normalized || raw)
    if (normalized) exact.push(normalized)
    if (key) keys.push(key)
  }
  if (!exact.length && !keys.length) return []
  const r = await pool.query(
    `SELECT token FROM device_tokens
     WHERE phone = ANY($1::text[])
        OR right(regexp_replace(phone, '\\D', '', 'g'), 9) = ANY($2::text[])`,
    [exact, keys],
  )
  return [...new Set(r.rows.map((x) => x.token))]
}

async function tokensFor({ phone, phones, tokens }) {
  if (Array.isArray(tokens) && tokens.length) return [...new Set(tokens.map(String))]
  if (phone) return tokensForPhones([phone])
  if (Array.isArray(phones) && phones.length) return tokensForPhones(phones)
  const r = await pool.query('SELECT token FROM device_tokens')
  return r.rows.map((x) => x.token)
}

function messagePayload({
  id,
  title,
  body,
  phone,
  phones,
  topic,
  audience,
  targetCount,
  status,
  successCount,
  failureCount,
  error,
  ok,
  detail,
}) {
  return {
    id,
    title,
    body,
    phone: phone ? String(phone) : null,
    phones: Array.isArray(phones) ? phones.map(String) : null,
    topic: topic ? String(topic) : null,
    audience: String(audience || topic || 'all'),
    targetCount,
    status,
    successCount,
    failureCount,
    error: error || null,
    ok,
    detail: detail || '',
    createdAt: new Date().toISOString(),
  }
}

async function insertMessage(row) {
  await pool.query(
    `INSERT INTO notification_messages (id, title, body, phone, phones, topic, audience, status, success_count, failure_count, error_message, target_count, ok, detail, created_at)
     VALUES ($1,$2,$3,$4,$5::jsonb,$6,$7,$8,$9,$10,$11,$12,$13,$14,NOW())`,
    [
      row.id,
      row.title,
      row.body,
      row.phone,
      JSON.stringify(Array.isArray(row.phones) ? row.phones : []),
      row.topic,
      row.audience,
      row.status,
      row.successCount,
      row.failureCount,
      row.error,
      row.targetCount,
      row.ok,
      row.detail,
    ],
  )
}

export async function sendPush({ title, body, phone, phones, tokens, topic, audience, data }) {
  const cleanTitle = String(title || '').trim()
  const cleanBody = String(body || '').trim()
  if (!cleanTitle || !cleanBody) throw new Error('title_and_body_required')
  const fcm = getMessaging()
  const targets = topic ? [] : await tokensFor({ phone, phones, tokens })
  const targetCount = topic ? 1 : targets.length
  const audienceLabel = String(audience || topic || 'all')
  const dataPayload = {}
  if (data && typeof data === 'object') {
    for (const [key, value] of Object.entries(data)) {
      if (value == null) continue
      dataPayload[String(key)] = String(value)
    }
  }

  if (!fcm) {
    const stored = messagePayload({
      id: `n_${randomUUID().slice(0, 12)}`,
      title: cleanTitle,
      body: cleanBody,
      phone,
      phones,
      topic,
      audience: audienceLabel,
      targetCount,
      status: 'stored_only',
      successCount: 0,
      failureCount: 0,
      error: initError || 'FCM not configured',
      ok: true,
      detail: initError || 'FCM not configured',
    })
    await insertMessage(stored)
    return stored
  }

  if (!topic && targets.length === 0) {
    throw new Error('No registered device tokens. Users must open the app while signed in.')
  }

  const baseMessage = {
    notification: { title: cleanTitle, body: cleanBody },
    data: dataPayload,
    android: {
      priority: 'high',
      notification: { channelId: 'chkela_default' },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          'content-available': 1,
        },
      },
    },
  }

  let ok = true
  let detail = ''
  let successCount = 0
  let failureCount = 0
  try {
    if (topic) {
      await fcm.send({ ...baseMessage, topic })
      successCount = 1
    } else if (targets.length === 1) {
      await fcm.send({ ...baseMessage, token: targets[0] })
      successCount = 1
    } else {
      const result = await fcm.sendEachForMulticast({
        tokens: targets,
        ...baseMessage,
      })
      successCount = Number(result.successCount || 0)
      failureCount = Number(result.failureCount || 0)
      if (successCount === 0 && failureCount > 0) {
        ok = false
        detail = 'All multicast deliveries failed'
      }
    }
  } catch (error) {
    ok = false
    detail = error instanceof Error ? error.message : String(error)
    failureCount = topic ? 1 : targets.length
  }

  const row = messagePayload({
    id: `n_${randomUUID().slice(0, 12)}`,
    title: cleanTitle,
    body: cleanBody,
    phone,
    phones,
    topic,
    audience: audienceLabel,
    targetCount,
    status: ok ? 'sent' : 'failed',
    successCount,
    failureCount,
    error: detail || null,
    ok,
    detail,
  })
  await insertMessage(row)
  return row
}

