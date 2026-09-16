import {
  getThread,
  listInbox,
  markRead,
  sendMessage,
} from '../services/chat.mjs'
import { sendPush } from '../services/push.mjs'
import {
  phoneFromSession,
  requireUser,
} from '../services/auth_guards.mjs'

export default async function chatRoutes(app) {
  app.get('/api/chat/inbox', async (req) => {
    await requireUser(req)
    const phone = phoneFromSession(req, req.query?.phone)
    return listInbox(phone)
  })

  app.get('/api/chat/thread', async (req) => {
    await requireUser(req)
    const phone = phoneFromSession(req, req.query?.phone)
    const { peerId, since, limit } = req.query
    return getThread({ phone, peerId, since, limit })
  })

  app.post('/api/chat/send', async (req) => {
    await requireUser(req)
    const body = { ...(req.body || {}) }
    body.phone = phoneFromSession(req, body.phone)
    const result = await sendMessage(body)
    if (result.notifyPhone) {
      try {
        await sendPush({
          phone: result.notifyPhone,
          title: result.senderName || 'New message',
          body: result.preview || 'Sent you a message on Chkela',
          audience: 'phone',
        })
      } catch (_) {}
    }
    return {
      conversationId: result.conversationId,
      peer: result.peer,
      message: result.message,
    }
  })

  app.post('/api/chat/read', async (req) => {
    await requireUser(req)
    const body = { ...(req.body || {}) }
    body.phone = phoneFromSession(req, body.phone)
    return markRead(body)
  })
}
