import { requireAdminRequest } from '../adminAuth.mjs'
import { createGiftCodeStore } from './store.mjs'
import { createStudentsStore } from '../students/store.mjs'

export function giftCodesApiPlugin({ giftCodesFile, studentsFile }) {
  const gifts = createGiftCodeStore(giftCodesFile)
  const students = createStudentsStore(studentsFile)

  return {
    name: 'chkela-gift-codes-api',
    configureServer(server) {
      server.middlewares.use(apiMiddleware(gifts, students))
    },
    configurePreviewServer(server) {
      server.middlewares.use(apiMiddleware(gifts, students))
    },
  }
}

function apiMiddleware(gifts, students) {
  return (req, res, next) => {
    const rawUrl = req.url || ''
    const isGift = rawUrl.startsWith('/api/gift-codes')
    const isStudent = rawUrl.startsWith('/api/students')
    if (!isGift && !isStudent) {
      next()
      return
    }

    if (req.method === 'OPTIONS') {
      res.statusCode = 204
      res.setHeader('Access-Control-Allow-Origin', '*')
      res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
      res.end()
      return
    }

    Promise.resolve()
      .then(async () => {
        const url = new URL(rawUrl, 'http://localhost')
        const path = url.pathname.replace(/\/$/, '') || '/'

        const isClaim = req.method === 'POST' && path === '/api/gift-codes/claim'
        const needsAdmin =
          !isClaim &&
          (path.startsWith('/api/gift-codes') || path.startsWith('/api/students'))
        if (needsAdmin && !requireAdminRequest(req, res)) return

        if (req.method === 'GET' && path === '/api/students') {
          sendJson(res, 200, { students: students.list() })
          return
        }

        if (req.method === 'POST' && path === '/api/students') {
          const body = await readBody(req)
          const student = students.upsert({
            name: body.name,
            phone: body.phone,
            status: body.status,
          })
          sendJson(res, 201, { student })
          return
        }

        if (req.method === 'GET' && path === '/api/gift-codes') {
          sendJson(res, 200, { codes: gifts.list() })
          return
        }

        if (req.method === 'POST' && path === '/api/gift-codes') {
          const body = await readBody(req)
          const created = gifts.create(Number(body.amountBirr))
          sendJson(res, 201, { code: created })
          return
        }

        if (req.method === 'POST' && path === '/api/gift-codes/claim') {
          const body = await readBody(req)
          const result = gifts.claim(
            String(body.code || ''),
            String(body.phone || body.claimedBy || ''),
            students,
          )
          sendJson(res, result.ok ? 200 : 400, result)
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
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
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
