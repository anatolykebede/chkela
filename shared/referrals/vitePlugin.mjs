import { requireAdminRequest } from '../adminAuth.mjs'
import {
  assertPhoneMatchesSession,
  requireUserRequest,
} from '../sessionAuth.mjs'
import { createReferralStore } from './store.mjs'

export function referralsApiPlugin({ referralsFile }) {
  const referrals = createReferralStore(referralsFile)

  return {
    name: 'chkela-referrals-api',
    configureServer(server) {
      server.middlewares.use(apiMiddleware(referrals))
    },
    configurePreviewServer(server) {
      server.middlewares.use(apiMiddleware(referrals))
    },
  }
}

function apiMiddleware(referrals) {
  return (req, res, next) => {
    const rawUrl = req.url || ''
    if (!rawUrl.startsWith('/api/referrals')) {
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

        if (req.method === 'GET' && path === '/api/referrals') {
          if (!requireAdminRequest(req, res)) return
          sendJson(res, 200, {
            referrals: referrals.list(),
            balances: referrals.listBalances(),
          })
          return
        }

        if (req.method === 'GET' && path === '/api/referrals/me') {
          const sessionPhone = requireUserRequest(req, res)
          if (!sessionPhone) return
          if (!assertPhoneMatchesSession(sessionPhone, url.searchParams.get('phone'), res)) {
            return
          }
          const me = referrals.me(sessionPhone)
          sendJson(res, 200, me)
          return
        }

        if (req.method === 'GET' && path === '/api/referrals/discount') {
          const sessionPhone = requireUserRequest(req, res)
          if (!sessionPhone) return
          if (!assertPhoneMatchesSession(sessionPhone, url.searchParams.get('phone'), res)) {
            return
          }
          const result = referrals.discountFor(sessionPhone)
          sendJson(res, result.ok ? 200 : 400, result)
          return
        }

        if (req.method === 'POST' && path === '/api/referrals/redeem') {
          const sessionPhone = requireUserRequest(req, res)
          if (!sessionPhone) return
          const body = await readBody(req)
          if (
            !assertPhoneMatchesSession(
              sessionPhone,
              body.inviteePhone || body.phone,
              res,
            )
          ) {
            return
          }
          const result = referrals.redeem(String(body.code || ''), sessionPhone)
          sendJson(res, result.ok ? 200 : 400, result)
          return
        }

        if (req.method === 'POST' && path === '/api/referrals/purchase') {
          const sessionPhone = requireUserRequest(req, res)
          if (!sessionPhone) return
          const body = await readBody(req)
          if (
            !assertPhoneMatchesSession(
              sessionPhone,
              body.inviteePhone || body.phone,
              res,
            )
          ) {
            return
          }
          const result = referrals.recordPurchase(
            sessionPhone,
            body.amountEtb ?? body.amount,
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
