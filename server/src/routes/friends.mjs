import {
  displayNameForPhone,
  listForPhone,
  normalizePhone,
  phoneForTarget,
  recordProfileView,
  removeFriend,
  requestFriend,
  respondFriend,
  upsertProfile,
} from '../services/friends.mjs'
import { sendPush } from '../services/push.mjs'
import {
  phoneFromSession,
  requireUser,
} from '../services/auth_guards.mjs'

export default async function friendsRoutes(app) {
  app.get('/api/friends', async (req) => {
    await requireUser(req)
    const phone = phoneFromSession(req, req.query?.phone)
    return listForPhone(phone)
  })

  app.post('/api/friends/profile', async (req) => {
    await requireUser(req)
    const body = { ...(req.body || {}) }
    body.phone = phoneFromSession(req, body.phone)
    const profile = await upsertProfile(body)
    return { profile }
  })

  app.post('/api/friends/request', async (req) => {
    await requireUser(req)
    const body = { ...(req.body || {}) }
    body.phone = phoneFromSession(req, body.phone)
    const result = await requestFriend(body)
    await notifyFriendRequest(body, result)
    return result
  })

  app.post('/api/friends/respond', async (req) => {
    await requireUser(req)
    const body = { ...(req.body || {}) }
    body.phone = phoneFromSession(req, body.phone)
    const result = await respondFriend(body)
    await notifyFriendRespond(body, result)
    return result
  })

  app.post('/api/friends/remove', async (req) => {
    await requireUser(req)
    const body = { ...(req.body || {}) }
    body.phone = phoneFromSession(req, body.phone)
    return removeFriend(body)
  })

  app.post('/api/friends/view', async (req) => {
    await requireUser(req)
    const body = { ...(req.body || {}) }
    body.phone = phoneFromSession(req, body.phone)
    const view = await recordProfileView(body)
    if (view.notified && view.targetPhone) {
      try {
        await sendPush({
          phone: view.targetPhone,
          title: 'Profile view',
          body: `${view.viewerName} viewed your profile on the map`,
          audience: 'phone',
        })
      } catch (_) {}
    }
    return view
  })
}

async function notifyFriendRequest(body, result) {
  const viewerPhone = normalizePhone(body.phone)
  if (!viewerPhone) return
  const viewerName = await displayNameForPhone(viewerPhone)
  const targetPhone =
    (await phoneForTarget(body.targetId)) ||
    normalizePhone(result?.friendship?.toId)
  if (!targetPhone || targetPhone === viewerPhone) return

  if (result.state === 'outgoing') {
    try {
      await sendPush({
        phone: targetPhone,
        title: 'Friend request',
        body: `${viewerName} sent you a friend request on Chkela`,
        audience: 'phone',
      })
    } catch (_) {}
    return
  }

  if (result.state === 'friends') {
    try {
      await sendPush({
        phone: targetPhone,
        title: 'New friend',
        body: `${viewerName} is now your friend on Chkela`,
        audience: 'phone',
      })
    } catch (_) {}
  }
}

async function notifyFriendRespond(body, result) {
  const actorPhone = normalizePhone(body.phone)
  if (!actorPhone || result.state !== 'friends') return
  const actorName = await displayNameForPhone(actorPhone)
  const peerPhone =
    (await phoneForTarget(body.targetId)) ||
    normalizePhone(result?.friendship?.fromPhone) ||
    normalizePhone(result?.friendship?.toId)
  if (!peerPhone || peerPhone === actorPhone) return
  try {
    await sendPush({
      phone: peerPhone,
      title: 'Friend request accepted',
      body: `${actorName} accepted your friend request on Chkela`,
      audience: 'phone',
    })
  } catch (_) {}
}
