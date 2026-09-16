import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { pool, tx, migrateSchema } from './db.mjs'
import { normalizePhone, upsertProfile } from './services/friends.mjs'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(__dirname, '../../')

function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'))
  } catch {
    return fallback
  }
}

function toIso(v) {
  const d = new Date(v || Date.now())
  return Number.isNaN(d.getTime()) ? new Date().toISOString() : d.toISOString()
}

async function migrateFriends() {
  const file = path.join(root, 'shared/friends/data.json')
  const data = readJson(file, { profiles: {}, friendships: [], profileViews: {} })
  for (const profile of Object.values(data.profiles || {})) {
    await upsertProfile({
      phone: profile.phone,
      mapId: profile.mapId,
      displayName: profile.displayName,
      school: profile.school,
      bio: profile.bio,
      tagline: profile.tagline,
      grade: profile.grade,
      cityId: profile.cityId,
      subjects: profile.subjects || [],
      moodEmoji: profile.moodEmoji,
      moodLabel: profile.moodLabel,
    })
  }
  for (const f of data.friendships || []) {
    const from = normalizePhone(f.fromPhone)
    const toId = String(f.toId || '').trim()
    if (!from || !toId) continue
    await pool.query(
      `INSERT INTO friendships (id, from_phone, to_id, status, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6)
       ON CONFLICT (id) DO UPDATE SET
         from_phone=EXCLUDED.from_phone,
         to_id=EXCLUDED.to_id,
         status=EXCLUDED.status,
         created_at=EXCLUDED.created_at,
         updated_at=EXCLUDED.updated_at`,
      [
        String(f.id || `f_${Math.random().toString(36).slice(2, 10)}`),
        from,
        toId,
        f.status === 'accepted' ? 'accepted' : 'pending',
        toIso(f.createdAt),
        toIso(f.updatedAt || f.createdAt),
      ],
    )
  }
}

async function migrateChat() {
  const file = path.join(root, 'shared/chat/data.json')
  const data = readJson(file, { conversations: {}, messages: {} })
  await tx(async (client) => {
    for (const conv of Object.values(data.conversations || {})) {
      if (!conv?.id) continue
      const participants = Array.isArray(conv.participants) ? conv.participants : []
      if (participants.length !== 2) continue
      const [a, b] = [...participants].sort()
      await client.query(
        `INSERT INTO conversations (id, participant_a, participant_b, created_at, updated_at, last_message)
         VALUES ($1,$2,$3,$4,$5,$6::jsonb)
         ON CONFLICT (id) DO UPDATE SET
           participant_a=EXCLUDED.participant_a,
           participant_b=EXCLUDED.participant_b,
           created_at=EXCLUDED.created_at,
           updated_at=EXCLUDED.updated_at,
           last_message=EXCLUDED.last_message`,
        [
          conv.id,
          a,
          b,
          toIso(conv.createdAt),
          toIso(conv.updatedAt),
          JSON.stringify(conv.lastMessage || null),
        ],
      )
      const unread = conv.unread && typeof conv.unread === 'object' ? conv.unread : {}
      for (const [pk, count] of Object.entries(unread)) {
        await client.query(
          `INSERT INTO conversation_unread (conversation_id, participant_key, unread_count)
           VALUES ($1,$2,$3)
           ON CONFLICT (conversation_id, participant_key) DO UPDATE SET unread_count=EXCLUDED.unread_count`,
          [conv.id, String(pk), Number(count || 0)],
        )
      }
    }

    for (const [convId, list] of Object.entries(data.messages || {})) {
      if (!Array.isArray(list)) continue
      for (const m of list) {
        if (!m?.id) continue
        await client.query(
          `INSERT INTO messages (id, conversation_id, from_key, text, created_at)
           VALUES ($1,$2,$3,$4,$5)
           ON CONFLICT (id) DO UPDATE SET
             conversation_id=EXCLUDED.conversation_id,
             from_key=EXCLUDED.from_key,
             text=EXCLUDED.text,
             created_at=EXCLUDED.created_at`,
          [
            String(m.id),
            String(m.conversationId || convId),
            String(m.from || ''),
            String(m.text || ''),
            toIso(m.createdAt),
          ],
        )
      }
    }
  })
}

async function migrateTokens() {
  const file = path.join(root, 'shared/notifications/data.json')
  const data = readJson(file, { tokens: [] })
  for (const t of data.tokens || []) {
    if (!t?.token || !t?.phone) continue
    await pool.query(
      `INSERT INTO device_tokens (token, phone, platform, updated_at)
       VALUES ($1,$2,$3,$4)
       ON CONFLICT (token) DO UPDATE SET
         phone=EXCLUDED.phone,
         platform=EXCLUDED.platform,
         updated_at=EXCLUDED.updated_at`,
      [
        String(t.token),
        String(t.phone),
        String(t.platform || 'unknown'),
        toIso(t.updatedAt),
      ],
    )
  }
}

async function migrateSubscriptions() {
  const file = path.join(root, 'shared/subscriptions/data.json')
  const data = readJson(file, { subscriptions: [] })
  for (const sub of data.subscriptions || []) {
    if (!sub?.phone) continue
    await pool.query(
      `INSERT INTO subscriptions (id, phone, plan, status, expires_at, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       ON CONFLICT (id) DO UPDATE SET
         phone=EXCLUDED.phone,
         plan=EXCLUDED.plan,
         status=EXCLUDED.status,
         expires_at=EXCLUDED.expires_at,
         created_at=EXCLUDED.created_at,
         updated_at=EXCLUDED.updated_at`,
      [
        String(sub.id || `sub_${Math.random().toString(36).slice(2, 10)}`),
        String(sub.phone),
        String(sub.plan || 'plus'),
        String(sub.status || 'active'),
        sub.expiresAt ? toIso(sub.expiresAt) : null,
        toIso(sub.createdAt),
        toIso(sub.updatedAt || sub.createdAt),
      ],
    )
  }
}

await migrateSchema()
await migrateFriends()
await migrateChat()
await migrateTokens()
await migrateSubscriptions()
await pool.end()
console.log('Migration complete.')

