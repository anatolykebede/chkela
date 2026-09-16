import { createNotificationsStore } from './store.mjs'
import { createStudentsStore } from '../students/store.mjs'
import { createSubscriptionsStore } from '../subscriptions/store.mjs'
import { createAudienceResolver } from '../subscriptions/audiences.mjs'

export function notificationsApiPlugin({
  notificationsFile,
  serviceAccountPath,
  studentsFile,
  giftCodesFile,
  friendsFile,
  subscriptionsFile,
}) {
  const notifications = createNotificationsStore(notificationsFile, {
    serviceAccountPath,
  })
  const students = createStudentsStore(studentsFile)
  const subscriptions = createSubscriptionsStore(subscriptionsFile)
  const audiences = createAudienceResolver({
    notifications,
    students,
    subscriptions,
    giftCodesFile,
    friendsFile,
  })

  return {
    name: 'chkela-notifications-api',
    configureServer(server) {
      server.middlewares.use(
        apiMiddleware({ notifications, audiences, subscriptions }),
      )
    },
    configurePreviewServer(server) {
      server.middlewares.use(
        apiMiddleware({ notifications, audiences, subscriptions }),
      )
    },
  }
}

function apiMiddleware({ notifications, audiences, subscriptions }) {
  return (req, res, next) => {
    const rawUrl = req.url || ''
    if (
      !rawUrl.startsWith('/api/notifications') &&
      !rawUrl.startsWith('/api/subscriptions')
    ) {
      next()
      return
    }

    if (req.method === 'OPTIONS') {
      res.statusCode = 204
      cors(res)
      res.end()
      return
    }

    Promise.resolve()
      .then(async () => {
        const url = new URL(rawUrl, 'http://localhost')
        const path = url.pathname.replace(/\/$/, '') || '/'

        if (req.method === 'GET' && path === '/api/subscriptions') {
          sendJson(res, 200, { subscriptions: subscriptions.list() })
          return
        }

        if (req.method === 'POST' && path === '/api/subscriptions') {
          const body = await readBody(req)
          const item = subscriptions.upsert(body)
          sendJson(res, 200, { subscription: item })
          return
        }

        if (req.method === 'GET' && path === '/api/notifications/status') {
          sendJson(res, 200, notifications.status())
          return
        }

        if (req.method === 'GET' && path === '/api/notifications/tokens') {
          sendJson(res, 200, { tokens: notifications.listTokens() })
          return
        }

        if (req.method === 'GET' && path === '/api/notifications/audiences') {
          sendJson(res, 200, { audiences: audiences.listWithCounts() })
          return
        }

        if (req.method === 'GET' && path === '/api/notifications') {
          sendJson(res, 200, { messages: notifications.listMessages() })
          return
        }

        if (req.method === 'POST' && path === '/api/notifications/register') {
          const body = await readBody(req)
          const token = notifications.register({
            token: body.token,
            phone: body.phone,
            platform: body.platform,
          })
          sendJson(res, 201, { token })
          return
        }

        if (req.method === 'POST' && path === '/api/notifications/send') {
          const body = await readBody(req)
          const audienceId = String(body.audience || '').trim()
          let message

          if (audienceId && audienceId !== 'phone') {
            // Broadcast to every registered device — skip phone filtering.
            if (audienceId === 'all') {
              message = await notifications.send({
                title: body.title,
                body: body.body,
                audience: 'all',
              })
              sendJson(res, 200, {
                message,
                audience: {
                  id: 'all',
                  deviceCount: message.targetCount || 0,
                },
              })
              return
            }

            const resolved = audiences.resolve(audienceId)
            if (resolved.tokens.length === 0) {
              sendJson(res, 400, {
                error: `No devices in audience "${audienceId}". Only phones that opened the app and allowed notifications can receive pushes.`,
                audience: resolved,
              })
              return
            }
            message = await notifications.send({
              title: body.title,
              body: body.body,
              tokens: resolved.tokens,
              audience: audienceId,
            })
            sendJson(res, 200, { message, audience: resolved })
            return
          }

          message = await notifications.send({
            title: body.title,
            body: body.body,
            phone: body.phone,
            topic: body.topic,
            audience: body.phone ? 'phone' : 'all',
          })
          sendJson(res, 200, { message })
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

function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')
}

function sendJson(res, status, payload) {
  res.statusCode = status
  res.setHeader('Content-Type', 'application/json')
  cors(res)
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
