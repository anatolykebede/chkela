import { createFriendsStore } from './store.mjs'
import { createNotificationsStore } from '../notifications/store.mjs'

export function friendsApiPlugin({
  friendsFile,
  notificationsFile,
  serviceAccountPath,
}) {
  const friends = createFriendsStore(friendsFile)
  const notifications =
    notificationsFile != null
      ? createNotificationsStore(notificationsFile, { serviceAccountPath })
      : null

  return {
    name: 'chkela-friends-api',
    configureServer(server) {
      server.middlewares.use(apiMiddleware(friends, notifications))
    },
    configurePreviewServer(server) {
      server.middlewares.use(apiMiddleware(friends, notifications))
    },
  }
}

function apiMiddleware(friends, notifications) {
  return (req, res, next) => {
    const rawUrl = req.url || ''
    if (!rawUrl.startsWith('/api/friends')) {
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

        if (req.method === 'GET' && path === '/api/friends') {
          const phone = url.searchParams.get('phone')
          sendJson(res, 200, friends.listForPhone(phone))
          return
        }

        if (req.method === 'POST' && path === '/api/friends/profile') {
          const body = await readBody(req)
          const profile = friends.upsertProfile(body)
          sendJson(res, 200, { profile })
          return
        }

        if (req.method === 'POST' && path === '/api/friends/request') {
          const body = await readBody(req)
          const result = friends.request(body)
          sendJson(res, 200, result)
          await notifyFriendRequest(friends, notifications, body, result)
          return
        }

        if (req.method === 'POST' && path === '/api/friends/respond') {
          const body = await readBody(req)
          const result = friends.respond(body)
          sendJson(res, 200, result)
          await notifyFriendRespond(friends, notifications, body, result)
          return
        }

        if (req.method === 'POST' && path === '/api/friends/remove') {
          const body = await readBody(req)
          const result = friends.remove(body)
          sendJson(res, 200, result)
          return
        }

        if (req.method === 'POST' && path === '/api/friends/view') {
          const body = await readBody(req)
          const view = friends.recordProfileView(body)
          sendJson(res, 200, view)
          if (view.notified && view.targetPhone) {
            await pushQuiet(notifications, {
              phone: view.targetPhone,
              title: 'Profile view',
              body: `${view.viewerName} viewed your profile on the map`,
            })
          }
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

async function notifyFriendRequest(friends, notifications, body, result) {
  const viewerPhone = friends.normalizePhone(body.phone)
  const viewerName = friends.displayNameForPhone(viewerPhone)
  const targetPhone =
    friends.phoneForTarget(body.targetId) ||
    friends.normalizePhone(result?.friendship?.toId)

  if (!targetPhone || targetPhone === viewerPhone) return

  if (result.state === 'outgoing') {
    await pushQuiet(notifications, {
      phone: targetPhone,
      title: 'Friend request',
      body: `${viewerName} sent you a friend request on Chkela`,
    })
    return
  }

  if (result.state === 'friends') {
    await pushQuiet(notifications, {
      phone: targetPhone,
      title: 'New friend',
      body: `${viewerName} added you as a friend on Chkela`,
    })
  }
}

async function notifyFriendRespond(friends, notifications, body, result) {
  if (result.state !== 'friends') return
  const accepterPhone = friends.normalizePhone(body.phone)
  const accepterName = friends.displayNameForPhone(accepterPhone)
  const requesterPhone = friends.normalizePhone(result.friendship?.fromPhone)
  if (!requesterPhone || requesterPhone === accepterPhone) return

  await pushQuiet(notifications, {
    phone: requesterPhone,
    title: 'Friend request accepted',
    body: `${accepterName} accepted your friend request`,
  })
}

async function pushQuiet(notifications, { phone, title, body }) {
  if (!notifications || !phone) return
  try {
    await notifications.send({ title, body, phone })
  } catch (error) {
    console.error('[friends] push failed:', error)
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
