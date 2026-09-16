import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'

const EMPTY = { conversations: {}, messages: {} }
const MAX_TEXT = 2000
const MAX_MESSAGES_PER_THREAD = 500

export function createChatStore(filePath, { friends } = {}) {
  if (!friends) throw new Error('friends_store_required')
  ensureFile(filePath)

  function read() {
    try {
      const raw = readFileSync(filePath, 'utf8')
      const parsed = JSON.parse(raw)
      return {
        conversations:
          parsed.conversations && typeof parsed.conversations === 'object'
            ? parsed.conversations
            : {},
        messages:
          parsed.messages && typeof parsed.messages === 'object'
            ? parsed.messages
            : {},
      }
    } catch {
      return { conversations: {}, messages: {} }
    }
  }

  function write(data) {
    writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8')
  }

  function conversationIdFor(a, b) {
    const keys = [a, b].filter(Boolean).sort()
    if (keys.length !== 2 || keys[0] === keys[1]) return null
    return `c_${keys.join('__')}`
  }

  function peerSummary(peerId) {
    const peer = friends.resolvePeer(peerId)
    if (!peer) {
      return {
        id: String(peerId || ''),
        targetId: String(peerId || ''),
        name: String(peerId || 'Student'),
        initials: '?',
        kind: 'unknown',
      }
    }
    return {
      id: peer.id,
      targetId: peer.targetId,
      name: peer.name || peer.targetId,
      initials: peer.initials || '?',
      grade: peer.grade || '',
      school: peer.school || '',
      kind: peer.kind || 'phone',
    }
  }

  function assertCanMessage(fromPhone, peerId) {
    const phone = friends.normalizePhone(fromPhone)
    if (!phone) throw new Error('phone_required')
    const target = String(peerId || '').trim()
    if (!target) throw new Error('peer_required')

    const myKey = friends.participantKey(phone)
    const peerKey = friends.participantKey(target)
    if (!myKey || !peerKey) throw new Error('peer_not_found')
    if (myKey === peerKey) throw new Error('cannot_message_self')

    // Map demo peers are always messageable (local / demo delivery).
    if (friends.isMapPeer(target) || friends.isMapPeer(peerKey)) {
      return { phone, myKey, peerKey, peerId: peerKey }
    }

    if (!friends.areFriends(phone, target)) {
      throw new Error('friends_only')
    }
    return { phone, myKey, peerKey, peerId: peerKey }
  }

  function ensureConversation(data, myKey, peerKey) {
    const id = conversationIdFor(myKey, peerKey)
    if (!id) throw new Error('invalid_conversation')
    let row = data.conversations[id]
    if (!row) {
      const now = new Date().toISOString()
      row = {
        id,
        participants: [myKey, peerKey].sort(),
        createdAt: now,
        updatedAt: now,
        lastMessage: null,
        unread: { [myKey]: 0, [peerKey]: 0 },
      }
      data.conversations[id] = row
      data.messages[id] = []
    }
    return row
  }

  function listInbox(rawPhone) {
    const phone = friends.normalizePhone(rawPhone)
    if (!phone) throw new Error('phone_required')
    const myKey = friends.participantKey(phone)
    if (!myKey) throw new Error('phone_required')

    const data = read()
    const items = []
    for (const row of Object.values(data.conversations)) {
      const parts = Array.isArray(row.participants) ? row.participants : []
      if (!parts.includes(myKey)) continue
      const peerKey = parts.find((p) => p !== myKey)
      if (!peerKey) continue
      // Hide threads that were never messaged (legacy empties from old getThread).
      if (!row.lastMessage) continue
      // Drop threads that are no longer messageable (unfriended real users).
      if (
        !friends.isMapPeer(peerKey) &&
        !friends.areFriends(phone, peerKey)
      ) {
        continue
      }
      const unreadMap =
        row.unread && typeof row.unread === 'object' ? row.unread : {}
      const last = row.lastMessage
      items.push({
        conversationId: row.id,
        peer: peerSummary(peerKey),
        lastMessage: last
          ? {
              ...last,
              isMine: last.from === myKey,
            }
          : null,
        unread: Number(unreadMap[myKey] || 0),
        updatedAt: row.updatedAt,
      })
    }
    items.sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)))
    return { phone, conversations: items }
  }

  function getThread({ phone: rawPhone, peerId, since, limit }) {
    const { phone, myKey, peerKey } = assertCanMessage(rawPhone, peerId)
    const data = read()
    const id = conversationIdFor(myKey, peerKey)
    const conv = id ? data.conversations[id] : null

    // Do not create or rewrite the store on read/poll (avoids clobbering sends).
    if (!conv) {
      return {
        phone,
        conversationId: id || '',
        peer: peerSummary(peerKey),
        messages: [],
        unread: 0,
      }
    }

    let list = Array.isArray(data.messages[conv.id])
      ? [...data.messages[conv.id]]
      : []
    const sinceIso = String(since || '').trim()
    if (sinceIso) {
      list = list.filter((m) => String(m.createdAt) > sinceIso)
    }
    const cap = Math.min(Math.max(Number(limit) || 200, 1), 500)
    if (list.length > cap) list = list.slice(-cap)

    return {
      phone,
      conversationId: conv.id,
      peer: peerSummary(peerKey),
      messages: list.map((m) => ({
        ...m,
        isMine: m.from === myKey,
      })),
      unread: Number(conv.unread?.[myKey] || 0),
    }
  }

  function send({ phone: rawPhone, peerId, text: rawText }) {
    const text = String(rawText || '').trim()
    if (!text) throw new Error('text_required')
    if (text.length > MAX_TEXT) throw new Error('text_too_long')

    const { phone, myKey, peerKey } = assertCanMessage(rawPhone, peerId)
    const data = read()
    const conv = ensureConversation(data, myKey, peerKey)
    const now = new Date().toISOString()
    const message = {
      id: `m_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`,
      conversationId: conv.id,
      from: myKey,
      text,
      createdAt: now,
    }

    if (!Array.isArray(data.messages[conv.id])) data.messages[conv.id] = []
    data.messages[conv.id].push(message)
    if (data.messages[conv.id].length > MAX_MESSAGES_PER_THREAD) {
      data.messages[conv.id] = data.messages[conv.id].slice(
        -MAX_MESSAGES_PER_THREAD,
      )
    }

    conv.lastMessage = {
      id: message.id,
      text: message.text,
      from: message.from,
      createdAt: message.createdAt,
    }
    conv.updatedAt = now
    if (!conv.unread || typeof conv.unread !== 'object') {
      conv.unread = { [myKey]: 0, [peerKey]: 0 }
    }
    conv.unread[myKey] = 0
    conv.unread[peerKey] = Number(conv.unread[peerKey] || 0) + 1

    write(data)

    const recipientPhone = friends.phoneForTarget(peerKey) || friends.normalizePhone(peerKey)
    return {
      phone,
      conversationId: conv.id,
      peer: peerSummary(peerKey),
      message: { ...message, isMine: true },
      notifyPhone: recipientPhone && recipientPhone !== phone ? recipientPhone : null,
      preview: text.length > 80 ? `${text.slice(0, 77)}…` : text,
      senderName: friends.displayNameForPhone(phone),
    }
  }

  function markRead({ phone: rawPhone, peerId, conversationId }) {
    const phone = friends.normalizePhone(rawPhone)
    if (!phone) throw new Error('phone_required')
    const myKey = friends.participantKey(phone)
    if (!myKey) throw new Error('phone_required')

    const data = read()
    let conv = null
    if (conversationId && data.conversations[conversationId]) {
      conv = data.conversations[conversationId]
    } else if (peerId) {
      const peerKey = friends.participantKey(peerId)
      if (!peerKey) throw new Error('peer_not_found')
      const id = conversationIdFor(myKey, peerKey)
      conv = id ? data.conversations[id] : null
    }
    if (!conv) return { ok: true, unread: 0 }
    if (!Array.isArray(conv.participants) || !conv.participants.includes(myKey)) {
      throw new Error('not_participant')
    }
    if (!conv.unread || typeof conv.unread !== 'object') conv.unread = {}
    conv.unread[myKey] = 0
    write(data)
    return { ok: true, conversationId: conv.id, unread: 0 }
  }

  return {
    listInbox,
    getThread,
    send,
    markRead,
  }
}

function ensureFile(filePath) {
  const dir = dirname(filePath)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  if (!existsSync(filePath)) {
    writeFileSync(filePath, `${JSON.stringify(EMPTY, null, 2)}\n`, 'utf8')
  }
}
