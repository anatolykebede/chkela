import { randomUUID } from 'node:crypto'
import { pool, tx } from '../db.mjs'
import {
  areFriends,
  displayNameForPhone,
  isMapPeer,
  normalizePhone,
  participantKey,
  phoneForTarget,
  resolvePeer,
} from './friends.mjs'

const MAX_TEXT = 2000
const MAX_MESSAGES_PER_THREAD = 500

function conversationIdFor(a, b) {
  const keys = [a, b].filter(Boolean).sort()
  if (keys.length !== 2 || keys[0] === keys[1]) return null
  return `c_${keys.join('__')}`
}

async function peerSummary(peerId) {
  const peer = await resolvePeer(peerId)
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

async function assertCanMessage(fromPhone, peerId) {
  const phone = normalizePhone(fromPhone)
  if (!phone) throw new Error('phone_required')
  const target = String(peerId || '').trim()
  if (!target) throw new Error('peer_required')
  const myKey = await participantKey(phone)
  const peerKey = await participantKey(target)
  if (!myKey || !peerKey) throw new Error('peer_not_found')
  if (myKey === peerKey) throw new Error('cannot_message_self')
  if (isMapPeer(target) || isMapPeer(peerKey)) return { phone, myKey, peerKey }
  if (!(await areFriends(phone, target))) throw new Error('friends_only')
  return { phone, myKey, peerKey }
}

export async function listInbox(rawPhone) {
  const phone = normalizePhone(rawPhone)
  if (!phone) throw new Error('phone_required')
  const myKey = await participantKey(phone)
  if (!myKey) throw new Error('phone_required')

  const r = await pool.query(
    `SELECT c.id, c.participant_a, c.participant_b, c.updated_at, c.last_message,
            COALESCE(u.unread_count,0) AS unread_count
     FROM conversations c
     LEFT JOIN conversation_unread u
       ON u.conversation_id=c.id AND u.participant_key=$1
     WHERE c.participant_a=$1 OR c.participant_b=$1
     ORDER BY c.updated_at DESC`,
    [myKey],
  )
  const out = []
  for (const row of r.rows) {
    const peerKey = row.participant_a === myKey ? row.participant_b : row.participant_a
    if (!peerKey || !row.last_message) continue
    if (!isMapPeer(peerKey) && !(await areFriends(phone, peerKey))) continue
    out.push({
      conversationId: row.id,
      peer: await peerSummary(peerKey),
      lastMessage: {
        ...row.last_message,
        isMine: row.last_message?.from === myKey,
      },
      unread: Number(row.unread_count || 0),
      updatedAt: row.updated_at?.toISOString?.() || String(row.updated_at || ''),
    })
  }
  return { phone, conversations: out }
}

export async function getThread({ phone: rawPhone, peerId, since, limit }) {
  const { phone, myKey, peerKey } = await assertCanMessage(rawPhone, peerId)
  const id = conversationIdFor(myKey, peerKey)
  const conv = await pool.query('SELECT id FROM conversations WHERE id=$1', [id])
  if (!conv.rows[0]) {
    return { phone, conversationId: id || '', peer: await peerSummary(peerKey), messages: [], unread: 0 }
  }
  const cap = Math.min(Math.max(Number(limit) || 200, 1), 500)
  const sinceIso = String(since || '').trim()
  const params = [id]
  let where = 'WHERE conversation_id=$1'
  if (sinceIso) {
    params.push(sinceIso)
    where += ' AND created_at > $2::timestamptz'
  }
  params.push(cap)
  const mr = await pool.query(
    `SELECT id, conversation_id, from_key AS "from", text, created_at
     FROM messages
     ${where}
     ORDER BY created_at ASC
     LIMIT $${params.length}`,
    params,
  )
  const ur = await pool.query(
    'SELECT unread_count FROM conversation_unread WHERE conversation_id=$1 AND participant_key=$2',
    [id, myKey],
  )
  return {
    phone,
    conversationId: id,
    peer: await peerSummary(peerKey),
    messages: mr.rows.map((m) => ({
      id: m.id,
      conversationId: m.conversation_id,
      from: m.from,
      text: m.text,
      createdAt: m.created_at?.toISOString?.() || String(m.created_at || ''),
      isMine: m.from === myKey,
    })),
    unread: Number(ur.rows[0]?.unread_count || 0),
  }
}

export async function sendMessage({ phone: rawPhone, peerId, text: rawText }) {
  const text = String(rawText || '').trim()
  if (!text) throw new Error('text_required')
  if (text.length > MAX_TEXT) throw new Error('text_too_long')
  const { phone, myKey, peerKey } = await assertCanMessage(rawPhone, peerId)
  const conversationId = conversationIdFor(myKey, peerKey)
  const now = new Date().toISOString()
  const msgId = `m_${randomUUID().slice(0, 12)}`
  await tx(async (client) => {
    await client.query(
      `INSERT INTO conversations (id, participant_a, participant_b, created_at, updated_at, last_message)
       VALUES ($1,$2,$3,$4,$4,$5::jsonb)
       ON CONFLICT (id) DO UPDATE SET updated_at=EXCLUDED.updated_at, last_message=EXCLUDED.last_message`,
      [
        conversationId,
        [myKey, peerKey].sort()[0],
        [myKey, peerKey].sort()[1],
        now,
        JSON.stringify({ id: msgId, text, from: myKey, createdAt: now }),
      ],
    )
    await client.query(
      'INSERT INTO messages (id, conversation_id, from_key, text, created_at) VALUES ($1,$2,$3,$4,$5)',
      [msgId, conversationId, myKey, text, now],
    )
    await client.query(
      `DELETE FROM messages
       WHERE conversation_id=$1
         AND id NOT IN (
           SELECT id FROM messages WHERE conversation_id=$1 ORDER BY created_at DESC LIMIT $2
         )`,
      [conversationId, MAX_MESSAGES_PER_THREAD],
    )
    // Lock unread rows in sorted participant order to avoid A↔B deadlocks.
    const [k1, k2] = [myKey, peerKey].slice().sort()
    await client.query(
      `INSERT INTO conversation_unread (conversation_id, participant_key, unread_count)
       VALUES
         ($1,$2, CASE WHEN $2 = $4 THEN 0 ELSE 1 END),
         ($1,$3, CASE WHEN $3 = $4 THEN 0 ELSE 1 END)
       ON CONFLICT (conversation_id, participant_key)
       DO UPDATE SET unread_count =
         CASE WHEN conversation_unread.participant_key = $4 THEN 0
              ELSE conversation_unread.unread_count + 1 END`,
      [conversationId, k1, k2, myKey],
    )
  })
  const recipientPhone = (await phoneForTarget(peerKey)) || normalizePhone(peerKey)
  return {
    phone,
    conversationId,
    peer: await peerSummary(peerKey),
    message: { id: msgId, conversationId, from: myKey, text, createdAt: now, isMine: true },
    notifyPhone: recipientPhone && recipientPhone !== phone ? recipientPhone : null,
    preview: text.length > 80 ? `${text.slice(0, 77)}…` : text,
    senderName: await displayNameForPhone(phone),
  }
}

export async function markRead({ phone: rawPhone, peerId, conversationId }) {
  const phone = normalizePhone(rawPhone)
  if (!phone) throw new Error('phone_required')
  const myKey = await participantKey(phone)
  if (!myKey) throw new Error('phone_required')
  let convId = String(conversationId || '').trim()
  if (!convId && peerId) {
    const peerKey = await participantKey(peerId)
    if (!peerKey) throw new Error('peer_not_found')
    convId = conversationIdFor(myKey, peerKey) || ''
  }
  if (!convId) return { ok: true, unread: 0 }
  const p = await pool.query('SELECT 1 FROM conversations WHERE id=$1 AND (participant_a=$2 OR participant_b=$2)', [convId, myKey])
  if (!p.rows[0]) throw new Error('not_participant')
  await pool.query(
    `INSERT INTO conversation_unread (conversation_id, participant_key, unread_count)
     VALUES ($1,$2,0)
     ON CONFLICT (conversation_id, participant_key) DO UPDATE SET unread_count=0`,
    [convId, myKey],
  )
  return { ok: true, conversationId: convId, unread: 0 }
}

