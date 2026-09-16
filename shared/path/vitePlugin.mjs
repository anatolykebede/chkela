import { isMutatingMethod, requireAdminRequest } from '../adminAuth.mjs'
import { createPathStore } from './store.mjs'
import { createPathProgressStore } from './progressStore.mjs'

/** Shared with Flutter via `--dart-define=CHKELA_PATH_PROGRESS_SECRET=...`. */
export function pathProgressSecret() {
  const fromEnv = String(process.env.CHKELA_PATH_PROGRESS_SECRET || '').trim()
  if (fromEnv) return fromEnv
  if (process.env.NODE_ENV === 'production') {
    throw new Error('CHKELA_PATH_PROGRESS_SECRET is required in production')
  }
  return 'chkela-local-path-progress'
}

export function pathApiPlugin({ pathFile, assetsPathFile, progressFile }) {
  const store = createPathStore(pathFile, { assetsFile: assetsPathFile })
  const progress = createPathProgressStore(
    progressFile || pathFile.replace(/data\.json$/, 'progress.json'),
  )

  return {
    name: 'chkela-path-api',
    configureServer(server) {
      server.middlewares.use(apiMiddleware(store, progress))
    },
    configurePreviewServer(server) {
      server.middlewares.use(apiMiddleware(store, progress))
    },
  }
}

function apiMiddleware(store, progress) {
  return (req, res, next) => {
    const rawUrl = req.url || ''
    if (!rawUrl.startsWith('/api/path')) {
      next()
      return
    }

    if (req.method === 'OPTIONS') {
      res.statusCode = 204
      cors(res, req)
      res.end()
      return
    }

    Promise.resolve()
      .then(async () => {
        const url = new URL(rawUrl, 'http://localhost')
        const pathname = url.pathname.replace(/\/$/, '') || '/'

        if (req.method === 'GET' && pathname === '/api/path') {
          sendJson(res, 200, { catalog: store.list() }, req)
          return
        }

        if (req.method === 'GET' && pathname === '/api/path/progress') {
          const phone = url.searchParams.get('phone')
          if (phone) {
            if (!authorizeProgress(req)) {
              sendJson(res, 401, { error: 'unauthorized' }, req)
              return
            }
            sendJson(res, 200, { progress: progress.findByPhone(phone) }, req)
            return
          }
          // Full dump requires admin JWT (not the client path secret).
          if (!requireAdminRequest(req, res)) return
          sendJson(res, 200, { progress: progress.list() }, req)
          return
        }

        if (req.method === 'POST' && pathname === '/api/path/progress') {
          if (!authorizeProgress(req)) {
            sendJson(res, 401, { error: 'unauthorized' }, req)
            return
          }
          const body = await readBody(req)
          const saved = await progress.upsert(body)
          sendJson(res, 200, { progress: saved }, req)
          return
        }

        if (
          isMutatingMethod(req.method) &&
          pathname.startsWith('/api/path') &&
          pathname !== '/api/path/progress'
        ) {
          if (!requireAdminRequest(req, res)) return
        }

        const upsertMatch = pathname.match(/^\/api\/path\/([a-zA-Z]+)$/)
        if (req.method === 'POST' && upsertMatch) {
          const collection = upsertMatch[1]
          if (collection === 'progress') {
            sendJson(res, 404, { error: 'not_found' }, req)
            return
          }
          const body = await readBody(req)
          const item = store.upsert(collection, body)
          sendJson(res, 200, { item }, req)
          return
        }

        const deleteMatch = pathname.match(
          /^\/api\/path\/([a-zA-Z]+)\/([^/]+)$/,
        )
        if (req.method === 'DELETE' && deleteMatch) {
          const collection = deleteMatch[1]
          const id = decodeURIComponent(deleteMatch[2])
          store.remove(collection, id)
          sendJson(res, 200, { ok: true }, req)
          return
        }

        sendJson(res, 404, { error: 'not_found' }, req)
      })
      .catch((error) => {
        const message = error instanceof Error ? error.message : 'Server error'
        sendJson(res, 400, { error: message }, req)
      })
  }
}

/** Secrets the Flutter client may send (env override + local defaults). */
function acceptedProgressSecrets() {
  const primary = pathProgressSecret()
  const secrets = new Set([primary, 'chkela-local-path-progress'])
  // Older local .env value so a stale Flutter session still works in dev.
  if (process.env.NODE_ENV !== 'production') {
    secrets.add('chkela-dev-path-progress-change-me')
  }
  return secrets
}

function authorizeProgress(req) {
  const secrets = acceptedProgressSecrets()
  const header = String(
    req.headers['x-chkela-path-secret'] ||
      req.headers['x-path-secret'] ||
      '',
  ).trim()
  const bearer = String(req.headers.authorization || '')
  const token = bearer.toLowerCase().startsWith('bearer ')
    ? bearer.slice(7).trim()
    : ''
  return (header.length > 0 && secrets.has(header)) ||
    (token.length > 0 && secrets.has(token))
}

function cors(res, req) {
  const origin = String(req?.headers?.origin || '').trim()
  // Reflect browser Origin so Flutter web (localhost:8080 → 127.0.0.1:5173) works.
  res.setHeader('Access-Control-Allow-Origin', origin || '*')
  if (origin) res.setHeader('Vary', 'Origin')
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,DELETE,OPTIONS')
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, X-Chkela-Path-Secret, X-Path-Secret',
  )
}

function sendJson(res, status, payload, req) {
  res.statusCode = status
  res.setHeader('Content-Type', 'application/json')
  cors(res, req)
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
