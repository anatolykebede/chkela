import dotenv from 'dotenv'
import Fastify from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import rateLimit from '@fastify/rate-limit'
import { migrateSchema, pool } from './db.mjs'
import { isProduction } from './services/tokens.mjs'
import authRoutes from './routes/auth.mjs'
import adminRoutes from './routes/admin.mjs'
import chatRoutes from './routes/chat.mjs'
import friendsRoutes from './routes/friends.mjs'
import notificationsRoutes from './routes/notifications.mjs'
import usersRoutes from './routes/users.mjs'
import leaderboardRoutes from './routes/leaderboard.mjs'
import aiRoutes from './routes/ai.mjs'
import paymentRoutes from './routes/payments.mjs'

dotenv.config()

if (isProduction()) {
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is required in production')
  }
  if (
    process.env.DATABASE_URL.includes('postgres:postgres@') ||
    (process.env.DATABASE_URL.includes('@127.0.0.1') &&
      process.env.ALLOW_LOCAL_DB_IN_PROD !== '1')
  ) {
    throw new Error(
      'DATABASE_URL looks like a weak/local default. Set a production database or ALLOW_LOCAL_DB_IN_PROD=1 for intentional local prod tests.',
    )
  }
  for (const key of [
    'SESSION_JWT_SECRET',
    'ADMIN_JWT_SECRET',
    'ADMIN_PASSWORD',
    'CORS_ORIGINS',
  ]) {
    if (!String(process.env[key] || '').trim()) {
      throw new Error(`${key} is required in production`)
    }
  }
}

const trustProxyEnv = String(process.env.TRUST_PROXY || '').trim().toLowerCase()
const trustProxy =
  trustProxyEnv === '1' ||
  trustProxyEnv === 'true' ||
  (trustProxyEnv === '' && isProduction())

const app = Fastify({
  logger: isProduction()
    ? { level: 'warn' }
    : true,
  bodyLimit: 256 * 1024,
  trustProxy,
})

const corsOrigins = String(process.env.CORS_ORIGINS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean)

await app.register(helmet, {
  global: true,
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false,
})

await app.register(cors, {
  origin: (origin, cb) => {
    if (!origin) return cb(null, true)
    if (corsOrigins.length) {
      return cb(null, corsOrigins.includes(origin))
    }
    // Dev-only fallback when CORS_ORIGINS unset (never in production).
    if (isProduction()) return cb(null, false)
    if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin)) {
      return cb(null, true)
    }
    // LAN origins only when explicitly allowed for device testing.
    if (
      process.env.ALLOW_LAN_CORS === '1' &&
      /^https?:\/\/192\.168\.\d+\.\d+:\d+$/i.test(origin)
    ) {
      return cb(null, true)
    }
    return cb(null, false)
  },
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
})

await app.register(rateLimit, {
  global: true,
  max: Number(process.env.RATE_LIMIT_MAX || 120),
  timeWindow: '1 minute',
})

app.get('/health', async () => ({ ok: true }))

await app.register(authRoutes)
await app.register(adminRoutes)
await app.register(usersRoutes)
await app.register(leaderboardRoutes)
await app.register(aiRoutes)
await app.register(paymentRoutes)
await app.register(chatRoutes)
await app.register(friendsRoutes)
await app.register(notificationsRoutes)

app.setErrorHandler((error, _req, reply) => {
  const message = error instanceof Error ? error.message : 'Server error'
  let statusCode =
    typeof error.statusCode === 'number' ? error.statusCode : 400
  if (message === 'CORS origin denied') statusCode = 403
  return reply.code(statusCode).send({ error: message })
})

const port = Number(process.env.PORT || 3001)
const host = process.env.HOST || (isProduction() ? '127.0.0.1' : '0.0.0.0')

await migrateSchema()

// Fail fast if DB unreachable
await pool.query('SELECT 1')

await app.listen({ port, host })
