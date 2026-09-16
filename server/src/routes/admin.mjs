import {
  assertAdminPassword,
  httpError,
  signAdminToken,
} from '../services/tokens.mjs'

export default async function adminRoutes(app) {
  app.post(
    '/api/admin/login',
    {
      config: {
        rateLimit: {
          max: 10,
          timeWindow: '1 minute',
        },
      },
    },
    async (req) => {
      const password = String(req.body?.password || '')
      assertAdminPassword(password)
      const token = await signAdminToken()
      return { ok: true, token, expiresIn: '12h' }
    },
  )

  app.post('/api/admin/logout', async () => {
    // Client discards token; JWT is stateless.
    return { ok: true }
  })

  app.get('/api/admin/me', async (req) => {
    const { requireAdmin } = await import('../services/auth_guards.mjs')
    await requireAdmin(req)
    return { ok: true, role: 'admin' }
  })
}
