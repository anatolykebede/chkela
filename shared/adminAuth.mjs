/**
 * Shared admin JWT check for Vite middleware (dashboard CMS plugins).
 * Uses ADMIN_JWT_SECRET from process.env (load dotenv in dashboard vite if needed).
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

/** Verify HS256 JWT without jose (Vite Node context). */
export function verifyAdminBearer(authorizationHeader) {
  const header = String(authorizationHeader || '')
  const match = header.match(/^Bearer\s+(.+)$/i)
  if (!match) return { ok: false, error: 'missing_token' }
  const token = match[1].trim()
  const secret = textSecret('ADMIN_JWT_SECRET')
  if (!secret) return { ok: false, error: 'admin_secret_missing' }

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
  if (payload.role !== 'admin') return { ok: false, error: 'not_admin' }
  if (typeof payload.exp === 'number' && payload.exp * 1000 < Date.now()) {
    return { ok: false, error: 'expired' }
  }
  return { ok: true, payload }
}

export function requireAdminRequest(req, res) {
  const result = verifyAdminBearer(req.headers?.authorization)
  if (!result.ok) {
    res.statusCode = 401
    res.setHeader('Content-Type', 'application/json')
    res.end(JSON.stringify({ error: 'Admin sign in required' }))
    return false
  }
  return true
}

export function isMutatingMethod(method) {
  const m = String(method || 'GET').toUpperCase()
  return m !== 'GET' && m !== 'HEAD' && m !== 'OPTIONS'
}
