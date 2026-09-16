import { requireAdminRequest } from '../adminAuth.mjs'
import { createAppConfigStore } from './store.mjs'

export function appConfigApiPlugin({ appConfigFile }) {
  const config = createAppConfigStore(appConfigFile)

  return {
    name: 'chkela-app-config-api',
    configureServer(server) {
      server.middlewares.use(apiMiddleware(config))
    },
    configurePreviewServer(server) {
      server.middlewares.use(apiMiddleware(config))
    },
  }
}

function apiMiddleware(config) {
  return (req, res, next) => {
    const rawUrl = req.url || ''
    if (!rawUrl.startsWith('/api/app-config')) {
      next()
      return
    }

    if (req.method === 'OPTIONS') {
      res.statusCode = 204
      res.setHeader('Access-Control-Allow-Origin', '*')
      res.setHeader('Access-Control-Allow-Methods', 'GET,PUT,OPTIONS')
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
      res.end()
      return
    }

    Promise.resolve()
      .then(async () => {
        const url = new URL(rawUrl, 'http://localhost')
        const path = url.pathname.replace(/\/$/, '') || '/'

        if (req.method === 'GET' && path === '/api/app-config') {
          sendJson(res, 200, { config: config.get() })
          return
        }

        if (req.method === 'PUT' && path === '/api/app-config') {
          if (!requireAdminRequest(req, res)) return
          const body = await readBody(req)
          const updated = config.update(body.config || body)
          sendJson(res, 200, { config: updated })
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
  res.setHeader('Access-Control-Allow-Methods', 'GET,PUT,OPTIONS')
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
