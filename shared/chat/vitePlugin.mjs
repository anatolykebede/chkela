import { createChatStore } from './store.mjs'
import { createFriendsStore } from '../friends/store.mjs'
import { createNotificationsStore } from '../notifications/store.mjs'

export function chatApiPlugin({
  chatFile,
  friendsFile,
  notificationsFile,
  serviceAccountPath,
}) {
  const friends = createFriendsStore(friendsFile)
  const chat = createChatStore(chatFile, { friends })
  const notifications =
    notificationsFile != null
      ? createNotificationsStore(notificationsFile, { serviceAccountPath })
      : null

  return {
    name: 'chkela-chat-api',
    configureServer(server) {
      server.middlewares.use(apiMiddleware(chat, friends, notifications))
    },
    configurePreviewServer(server) {
      server.middlewares.use(apiMiddleware(chat, friends, notifications))
    },
  }
}

function apiMiddleware(chat, friends, notifications) {
  return (req, res, next) => {
    const rawUrl = req.url || ''
    if (!rawUrl.startsWith('/api/chat')) {
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

        if (req.method === 'GET' && path === '/api/chat/inbox') {
          const phone = url.searchParams.get('phone')
          sendJson(res, 200, chat.listInbox(phone))
          return
        }

        if (req.method === 'GET' && path === '/api/chat/thread') {
          const phone = url.searchParams.get('phone')
          const peerId = url.searchParams.get('peerId')
          const since = url.searchParams.get('since')
          const limit = url.searchParams.get('limit')
          sendJson(
            res,
            200,
            chat.getThread({ phone, peerId, since, limit }),
          )
          return
        }

        if (req.method === 'POST' && path === '/api/chat/send') {
          const body = await readBody(req)
          const result = chat.send(body)
          sendJson(res, 200, {
            conversationId: result.conversationId,
            peer: result.peer,
            message: result.message,
          })
          if (result.notifyPhone) {
            await pushQuiet(notifications, {
              phone: result.notifyPhone,
              title: result.senderName || 'New message',
              body: result.preview || 'Sent you a message on Chkela',
            })
          }
          return
        }

        if (req.method === 'POST' && path === '/api/chat/read') {
          const body = await readBody(req)
          sendJson(res, 200, chat.markRead(body))
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

async function pushQuiet(notifications, { phone, title, body }) {
  if (!notifications || !phone) return
  try {
    await notifications.send({ title, body, phone })
  } catch (error) {
    console.error('[chat] push failed:', error)
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
