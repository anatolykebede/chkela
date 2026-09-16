import { pool } from '../db.mjs'
import { registerToken, sendPush, status } from '../services/push.mjs'
import { listAudiencesWithCounts, resolveAudience } from '../services/audiences.mjs'
import { listSubscriptions, upsertSubscription } from '../services/subscriptions.mjs'
import { httpError } from '../services/tokens.mjs'
import {
  phoneFromSession,
  requireAdmin,
  requireUser,
} from '../services/auth_guards.mjs'

export default async function notificationRoutes(app) {
  app.get('/api/notifications/status', async (req) => {
    await requireAdmin(req)
    return status()
  })

  app.get('/api/subscriptions', async (req) => {
    await requireAdmin(req)
    return { subscriptions: await listSubscriptions() }
  })

  app.post('/api/subscriptions', async (req) => {
    await requireAdmin(req)
    const subscription = await upsertSubscription(req.body || {})
    return { subscription }
  })

  app.get('/api/notifications/tokens', async (req) => {
    await requireAdmin(req)
    const rows = await pool.query(
      'SELECT token, phone, platform, updated_at FROM device_tokens ORDER BY updated_at DESC',
    )
    return {
      tokens: rows.rows.map((x) => ({
        token: x.token,
        phone: x.phone,
        platform: x.platform,
        updatedAt: x.updated_at?.toISOString?.() || String(x.updated_at || ''),
      })),
    }
  })

  app.get('/api/notifications', async (req) => {
    await requireAdmin(req)
    const rows = await pool.query(
      'SELECT * FROM notification_messages ORDER BY created_at DESC LIMIT 300',
    )
    return {
      messages: rows.rows.map((x) => ({
        id: x.id,
        title: x.title,
        body: x.body,
        phone: x.phone || null,
        phones: Array.isArray(x.phones) ? x.phones : null,
        topic: x.topic || null,
        audience: x.audience,
        status: x.status || (x.ok ? 'sent' : 'failed'),
        successCount: Number(x.success_count || 0),
        failureCount: Number(x.failure_count || 0),
        error: x.error_message || null,
        targetCount: x.target_count,
        ok: x.ok,
        detail: x.detail,
        createdAt: x.created_at?.toISOString?.() || String(x.created_at || ''),
      })),
    }
  })

  app.get('/api/notifications/audiences', async (req) => {
    await requireAdmin(req)
    return { audiences: await listAudiencesWithCounts() }
  })

  app.post('/api/notifications/register', async (req, reply) => {
    await requireUser(req)
    const body = { ...(req.body || {}) }
    body.phone = phoneFromSession(req, body.phone)
    const token = await registerToken(body)
    reply.code(201)
    return { token }
  })

  app.post(
    '/api/notifications/send',
    {
      config: {
        rateLimit: { max: 20, timeWindow: '1 minute' },
      },
    },
    async (req) => {
      await requireAdmin(req)
      const body = req.body || {}
      const audienceId = String(body.audience || '').trim()
      if (audienceId && audienceId !== 'phone') {
        const resolved = await resolveAudience(audienceId)
        if (resolved.tokens.length === 0) {
          throw httpError(
            `No devices in audience "${audienceId}". Only phones that opened the app and allowed notifications can receive pushes.`,
          )
        }
        const msg = await sendPush({
          title: body.title,
          body: body.body,
          tokens: resolved.tokens,
          audience: audienceId,
        })
        return { message: msg, audience: resolved }
      }
      const msg = await sendPush({
        title: body.title,
        body: body.body,
        phone: body.phone,
        topic: body.topic,
        audience: body.phone ? 'phone' : 'all',
      })
      return { message: msg }
    },
  )
}
