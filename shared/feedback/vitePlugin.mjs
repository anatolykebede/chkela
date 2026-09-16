import { requireAdminRequest } from '../adminAuth.mjs'
import { createFeedbackStore } from './store.mjs'

export function feedbackApiPlugin({ feedbackFile }) {
  const feedback = createFeedbackStore(feedbackFile)

  return {
    name: 'chkela-feedback-api',
    configureServer(server) {
      server.middlewares.use(apiMiddleware(feedback))
    },
    configurePreviewServer(server) {
      server.middlewares.use(apiMiddleware(feedback))
    },
  }
}

function apiMiddleware(feedback) {
  return (req, res, next) => {
    const rawUrl = req.url || ''
    if (!rawUrl.startsWith('/api/feedback')) {
      next()
      return
    }

    if (req.method === 'OPTIONS') {
      res.statusCode = 204
      res.setHeader('Access-Control-Allow-Origin', '*')
      res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,OPTIONS')
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
      res.end()
      return
    }

    Promise.resolve()
      .then(async () => {
        const url = new URL(rawUrl, 'http://localhost')
        const path = url.pathname.replace(/\/$/, '') || '/'

        if (req.method === 'GET' && path === '/api/feedback') {
          if (!requireAdminRequest(req, res)) return
          sendJson(res, 200, { items: feedback.list() })
          return
        }

        if (req.method === 'POST' && path === '/api/feedback') {
          const body = await readBody(req)
          const created = feedback.create({
            message: body.message,
            phone: body.phone,
          })
          sendJson(res, 201, { item: created })
          return
        }

        const statusMatch = path.match(/^\/api\/feedback\/([^/]+)\/status$/)
        if (req.method === 'PATCH' && statusMatch) {
          if (!requireAdminRequest(req, res)) return
          const body = await readBody(req)
          const updated = feedback.setStatus(
            decodeURIComponent(statusMatch[1]),
            String(body.status || ''),
          )
          sendJson(res, 200, { item: updated })
          return
        }

        sendJson(res, 404, { error: 'not_found' })
      })
      .catch((error) => {
        const message = error instanceof Error ? error.message : 'Server error'
        sendJson(res, 400, { error: message })
      })
  }
}

function sendJson(res, status, payload) {
  res.statusCode = status
  res.setHeader('Content-Type', 'application/json')
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
  res.end(JSON.stringify(payload))
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = []
    req.on('data', (chunk) => chunks.push(chunk))
    req.on('end', () => {
      if (chunks.length === 0) {
        resolve({})
        return
      }
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')))
      } catch (error) {
        reject(error)
      }
    })
    req.on('error', reject)
  })
}
