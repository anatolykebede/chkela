/**
 * User session JWT check for Vite middleware (Flutter Bearer tokens).
 * Uses SESSION_JWT_SECRET (same as Fastify signUserToken).
 */
import { createHmac, timingSafeEqual } from 'node:crypto'

function b64urlToBuf(str) {
  const pad = '='.repeat((4 - (str.length % 4)) % 4)
  const b64 = (str + pad).replace(/-/g, '+').replace(/_/g, '/')
  return Buffer.from(b64, 'base64')
}

function textSecret(name) {
  return String(process.env[name] || '').trim()
}

export function normalizePhone(value) {
  const digits = String(value || '').replace(/\D/g, '')
  if (!digits) return ''
  if (digits.startsWith('251') && digits.length >= 12) return `+${digits}`
  if (digits.startsWith('0') && digits.length === 10) return `+251${digits.slice(1)}`
  if (digits.length === 9) return `+251${digits}`
  return value.startsWith('+') ? `+${digits}` : `+${digits}`
}

/** Verify HS256 user JWT without jose (Vite Node context). */
export function verifyUserBearer(authorizationHeader) {
  const header = String(authorizationHeader || '')
  const match = header.match(/^Bearer\s+(.+)$/i)
  if (!match) return { ok: false, error: 'missing_token' }
  const token = match[1].trim()
  const secret = textSecret('SESSION_JWT_SECRET')
  if (!secret) return { ok: false, error: 'session_secret_missing' }

  const parts = token.split('.')
  if (parts.length !== 3) return { ok: false, error: 'bad_token' }
  const [h, p, s] = parts
  const data = `${h}.${p}`
  const expected = createHmac('sha256', secret).update(data).digest()
  let actual
  try {
    actual = b64urlToBuf(s)
  } catch {
    return { ok: false, error: 'bad_token' }
  }
  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
    return { ok: false, error: 'bad_signature' }
  }

  let payload
  try {
    payload = JSON.parse(b64urlToBuf(p).toString('utf8'))
  } catch {
    return { ok: false, error: 'bad_payload' }
  }
  if (payload.role !== 'user') return { ok: false, error: 'not_user' }
  const phone = normalizePhone(payload.sub || payload.phone)
  if (!phone) return { ok: false, error: 'bad_payload' }
  if (typeof payload.exp === 'number' && payload.exp * 1000 < Date.now()) {
    return { ok: false, error: 'expired' }
  }
  return { ok: true, phone, payload }
}

/** @returns {string|null} session phone, or null after writing 401 */
export function requireUserRequest(req, res) {
  const result = verifyUserBearer(req.headers?.authorization)
  if (!result.ok) {
    res.statusCode = 401
    res.setHeader('Content-Type', 'application/json')
    res.end(JSON.stringify({ error: 'Sign in required' }))
    return null
  }
  return result.phone
}

export function assertPhoneMatchesSession(sessionPhone, requestedPhone, res) {
  const requested = normalizePhone(requestedPhone)
  if (requested && requested !== sessionPhone) {
    res.statusCode = 403
    res.setHeader('Content-Type', 'application/json')
    res.end(JSON.stringify({ error: 'Phone does not match session' }))
    return false
  }
  return true
}
