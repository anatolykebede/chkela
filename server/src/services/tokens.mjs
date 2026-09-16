import { timingSafeEqual } from 'node:crypto'
import { SignJWT, jwtVerify } from 'jose'

function textSecret(name, { required = true } = {}) {
  const value = String(process.env[name] || '').trim()
  if (!value && required) {
    const error = new Error(`${name} is not configured`)
    error.statusCode = 500
    throw error
  }
  return value
}

function keyFromEnv(name) {
  return new TextEncoder().encode(textSecret(name))
}

export function httpError(message, statusCode = 400) {
  const error = new Error(message)
  error.statusCode = statusCode
  return error
}

export async function signUserToken(phone) {
  const secret = keyFromEnv('SESSION_JWT_SECRET')
  return new SignJWT({ role: 'user', phone })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(phone)
    .setIssuedAt()
    .setExpirationTime('30d')
    .sign(secret)
}

export async function signAdminToken() {
  const secret = keyFromEnv('ADMIN_JWT_SECRET')
  return new SignJWT({ role: 'admin' })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject('admin')
    .setIssuedAt()
    .setExpirationTime('12h')
    .sign(secret)
}

export async function verifyUserToken(token) {
  const secret = keyFromEnv('SESSION_JWT_SECRET')
  const { payload } = await jwtVerify(token, secret)
  if (payload.role !== 'user' || typeof payload.sub !== 'string') {
    throw httpError('Invalid session', 401)
  }
  return { phone: payload.sub, role: 'user' }
}

export async function verifyAdminToken(token) {
  const secret = keyFromEnv('ADMIN_JWT_SECRET')
  const { payload } = await jwtVerify(token, secret)
  if (payload.role !== 'admin') {
    throw httpError('Admin access required', 401)
  }
  return { role: 'admin' }
}

export function bearerToken(req) {
  const header = req.headers?.authorization || req.headers?.Authorization
  if (typeof header !== 'string') return null
  const match = header.match(/^Bearer\s+(.+)$/i)
  return match ? match[1].trim() : null
}

export function assertAdminPassword(password) {
  const expected = textSecret('ADMIN_PASSWORD')
  const provided = String(password || '')
  const a = Buffer.from(provided)
  const b = Buffer.from(expected)
  if (a.length !== b.length || !timingSafeEqual(a, b)) {
    throw httpError('Invalid admin password', 401)
  }
}

export function isProduction() {
  return process.env.NODE_ENV === 'production'
}
