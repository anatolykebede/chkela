import { randomUUID } from 'node:crypto'
import { MAP_PEER_CATALOG } from './catalog.mjs'
import { pool } from '../db.mjs'

export function normalizePhone(value) {
  const digits = String(value || '').replace(/[^\d+]/g, '').trim()
  if (!digits) return null
  const compact = digits.replace(/(?!^)\+/g, '')
  const onlyDigits = compact.replace(/\D/g, '')
  if (onlyDigits.length < 9 || onlyDigits.length > 13) return null
  if (compact.startsWith('+')) return `+${onlyDigits}`
  if (onlyDigits.startsWith('251') && onlyDigits.length >= 12) return `+${onlyDigits}`
  if (onlyDigits.startsWith('0') && onlyDigits.length === 10) return `+251${onlyDigits.slice(1)}`
  if (onlyDigits.length === 9) return `+251${onlyDigits}`
  return `+${onlyDigits}`
}

function phoneKey(phone) {
  return String(phone || '').replace(/\D/g, '')
}

function initialsFromName(name) {
  const parts = String(name || '')
    .trim()
    .split(/\s+/)
    .filter(Boolean)
  if (parts.length === 0) return '?'
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase()
}

export function isMapPeer(targetId) {
  return Boolean(MAP_PEER_CATALOG[String(targetId || '').trim()])
}

export async function upsertProfile(body) {
  const phone = normalizePhone(body.phone)
  if (!phone) throw new Error('phone_required')
  let mapId = String(body.mapId || '').trim()
  if (!mapId || mapId === 'selam-tadesse' || mapId === 'me') {
    mapId = `u${phoneKey(phone)}`
  }
  const row = await pool.query(
    `INSERT INTO profiles (phone, map_id, display_name, school, bio, tagline, grade, city_id, subjects, mood_emoji, mood_label, updated_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb,$10,$11,NOW())
     ON CONFLICT (phone) DO UPDATE SET
       map_id=EXCLUDED.map_id,
       display_name=EXCLUDED.display_name,
       school=EXCLUDED.school,
       bio=EXCLUDED.bio,
       tagline=EXCLUDED.tagline,
       grade=EXCLUDED.grade,
       city_id=EXCLUDED.city_id,
       subjects=EXCLUDED.subjects,
       mood_emoji=EXCLUDED.mood_emoji,
       mood_label=EXCLUDED.mood_label,
       updated_at=NOW()
     RETURNING *`,
    [
      phone,
      mapId,
      String(body.displayName || '').trim(),
      String(body.school || '').trim(),
      String(body.bio || '').trim(),
      String(body.tagline || '').trim(),
      String(body.grade || '').trim(),
      String(body.cityId || '').trim(),
      JSON.stringify(Array.isArray(body.subjects) ? body.subjects.map(String).slice(0, 4) : []),
      String(body.moodEmoji || '').trim(),
      String(body.moodLabel || '').trim(),
    ],
  )
  return profileToJson(row.rows[0])
}

function profileToJson(row) {
  if (!row) return null
  return {
    phone: row.phone,
    mapId: row.map_id,
    displayName: row.display_name || '',
    school: row.school || '',
    bio: row.bio || '',
    tagline: row.tagline || '',
    grade: row.grade || '',
    cityId: row.city_id || '',
    subjects: Array.isArray(row.subjects) ? row.subjects : [],
    moodEmoji: row.mood_emoji || '',
    moodLabel: row.mood_label || '',
    updatedAt: row.updated_at?.toISOString?.() || String(row.updated_at || ''),
  }
}

async function profileByPhone(phone) {
  const key = normalizePhone(phone)
  if (!key) return null
  const r = await pool.query('SELECT * FROM profiles WHERE phone=$1 LIMIT 1', [key])
  return profileToJson(r.rows[0])
}

async function profileByMapId(mapId) {
  const id = String(mapId || '').trim()
  if (!id) return null
  if (MAP_PEER_CATALOG[id]) return { ...MAP_PEER_CATALOG[id], mapId: id }
  const r = await pool.query('SELECT * FROM profiles WHERE map_id=$1 OR phone=$1 LIMIT 1', [id])
  return profileToJson(r.rows[0])
}

export async function resolvePeer(targetId) {
  const id = String(targetId || '').trim()
  if (!id) return null
  if (MAP_PEER_CATALOG[id]) return { ...MAP_PEER_CATALOG[id], targetId: id, kind: 'map' }
  const asPhone = normalizePhone(id)
  if (asPhone) {
    const profile = await profileByPhone(asPhone)
    if (!profile) {
      return { targetId: asPhone, kind: 'phone', id: asPhone, name: asPhone, initials: '?', grade: '', school: '', subjects: [] }
    }
    return {
      targetId: asPhone,
      kind: 'phone',
      id: asPhone,
      name: profile.displayName || asPhone,
      initials: initialsFromName(profile.displayName || asPhone),
      grade: profile.grade || '',
      school: profile.school || '',
      subjects: profile.subjects || [],
      bio: profile.bio || '',
      mapId: profile.mapId || '',
    }
  }
  const byMap = await profileByMapId(id)
  if (!byMap) return null
  const phone = normalizePhone(byMap.phone)
  return {
    targetId: phone || id,
    kind: phone ? 'phone' : 'map',
    id: phone || byMap.mapId || id,
    name: byMap.displayName || byMap.name || id,
    initials: initialsFromName(byMap.displayName || byMap.name || id),
    grade: byMap.grade || '',
    school: byMap.school || '',
    subjects: byMap.subjects || [],
    bio: byMap.bio || '',
    mapId: byMap.mapId || '',
  }
}

async function findEdge(fromPhone, toId) {
  const from = normalizePhone(fromPhone)
  const to = String(toId || '').trim()
  const toPhone = normalizePhone(to)
  if (!from || !to) return null
  const r = await pool.query(
    `SELECT * FROM friendships
     WHERE from_phone = ANY($1::text[]) OR to_id = ANY($1::text[])
     ORDER BY updated_at DESC`,
    [[from, to, toPhone || to]],
  )
  return (
    r.rows.find((row) => {
      const a = normalizePhone(row.from_phone)
      const b = String(row.to_id || '').trim()
      const bPhone = normalizePhone(b)
      const sameDirection = a === from && (b === to || bPhone === toPhone)
      const reverse = a === (toPhone || to) && (b === from || bPhone === from)
      return sameDirection || reverse
    }) || null
  )
}

function edgeToItem(edge, peer) {
  return {
    friendshipId: edge.id,
    status: edge.status,
    peer,
    createdAt: edge.created_at?.toISOString?.() || String(edge.created_at || ''),
    updatedAt: edge.updated_at?.toISOString?.() || String(edge.updated_at || ''),
  }
}

export async function listForPhone(rawPhone) {
  const phone = normalizePhone(rawPhone)
  if (!phone) throw new Error('phone_required')
  const r = await pool.query(
    `SELECT * FROM friendships
     WHERE from_phone=$1 OR to_id=$1 OR to_id=$2
     ORDER BY updated_at DESC`,
    [phone, phoneKey(phone)],
  )
  const friends = []
  const incoming = []
  const outgoing = []
  for (const row of r.rows) {
    const iAmFrom = normalizePhone(row.from_phone) === phone
    const peerId = iAmFrom ? row.to_id : row.from_phone
    const peer =
      (await resolvePeer(peerId)) ||
      { targetId: peerId, id: peerId, name: String(peerId), initials: '?', grade: '', school: '', subjects: [], kind: 'unknown' }
    const item = edgeToItem(row, peer)
    if (row.status === 'accepted') friends.push(item)
    else if (row.status === 'pending') (iAmFrom ? outgoing : incoming).push(item)
  }
  return { phone, friends, incoming, outgoing }
}

export async function requestFriend({ phone: rawPhone, targetId }) {
  const phone = normalizePhone(rawPhone)
  const target = String(targetId || '').trim()
  if (!phone) throw new Error('phone_required')
  if (!target) throw new Error('target_required')
  if (normalizePhone(target) === phone || target === phone) throw new Error('cannot_friend_self')
  const peer = await resolvePeer(target)
  if (!peer) throw new Error('peer_not_found')
  const existing = await findEdge(phone, peer.targetId || target)
  const now = new Date().toISOString()
  if (existing) {
    if (existing.status === 'accepted') return { friendship: rowToFriendship(existing), state: 'friends' }
    if (existing.status === 'pending' && normalizePhone(existing.from_phone) !== phone) {
      const u = await pool.query('UPDATE friendships SET status=$1, updated_at=NOW() WHERE id=$2 RETURNING *', ['accepted', existing.id])
      return { friendship: rowToFriendship(u.rows[0]), state: 'friends' }
    }
    if (existing.status === 'pending') return { friendship: rowToFriendship(existing), state: 'outgoing' }
  }
  const autoAccept = isMapPeer(target) || isMapPeer(peer.id)
  try {
    const ins = await pool.query(
      `INSERT INTO friendships (id, from_phone, to_id, status, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$5) RETURNING *`,
      [`f_${randomUUID().slice(0, 12)}`, phone, peer.targetId || target, autoAccept ? 'accepted' : 'pending', now],
    )
    return { friendship: rowToFriendship(ins.rows[0]), state: autoAccept ? 'friends' : 'outgoing' }
  } catch (error) {
    if (error?.code !== '23505') throw error
    const raced = await findEdge(phone, peer.targetId || target)
    if (!raced) throw error
    if (raced.status === 'accepted') return { friendship: rowToFriendship(raced), state: 'friends' }
    if (normalizePhone(raced.from_phone) !== phone) {
      const u = await pool.query('UPDATE friendships SET status=$1, updated_at=NOW() WHERE id=$2 RETURNING *', ['accepted', raced.id])
      return { friendship: rowToFriendship(u.rows[0]), state: 'friends' }
    }
    return { friendship: rowToFriendship(raced), state: 'outgoing' }
  }
}

function rowToFriendship(row) {
  return {
    id: row.id,
    fromPhone: row.from_phone,
    toId: row.to_id,
    status: row.status,
    createdAt: row.created_at?.toISOString?.() || String(row.created_at || ''),
    updatedAt: row.updated_at?.toISOString?.() || String(row.updated_at || ''),
  }
}

export async function respondFriend({ phone: rawPhone, friendshipId, action }) {
  const phone = normalizePhone(rawPhone)
  if (!phone) throw new Error('phone_required')
  const id = String(friendshipId || '').trim()
  const act = String(action || '').trim().toLowerCase()
  if (!id) throw new Error('friendship_required')
  if (act !== 'accept' && act !== 'decline') throw new Error('action_must_be_accept_or_decline')
  const r = await pool.query('SELECT * FROM friendships WHERE id=$1 LIMIT 1', [id])
  const row = r.rows[0]
  if (!row) throw new Error('friendship_not_found')
  const toPhone = normalizePhone(row.to_id)
  const myProfile = await profileByPhone(phone)
  const iAmTarget = toPhone === phone || String(row.to_id) === phone || (myProfile?.mapId && myProfile.mapId === String(row.to_id))
  if (!iAmTarget) throw new Error('not_request_recipient')
  if (act === 'decline') {
    await pool.query('DELETE FROM friendships WHERE id=$1', [id])
    return { state: 'none' }
  }
  const u = await pool.query('UPDATE friendships SET status=$1, updated_at=NOW() WHERE id=$2 RETURNING *', ['accepted', id])
  return { friendship: rowToFriendship(u.rows[0]), state: 'friends' }
}

export async function removeFriend({ phone: rawPhone, targetId, friendshipId }) {
  const phone = normalizePhone(rawPhone)
  if (!phone) throw new Error('phone_required')
  if (friendshipId) {
    const r = await pool.query(
      `DELETE FROM friendships
       WHERE id=$1 AND (from_phone=$2 OR to_id=$2 OR to_id=$3)
       RETURNING id`,
      [String(friendshipId), phone, phoneKey(phone)],
    )
    if (!r.rowCount) throw new Error('friendship_not_found')
    return { state: 'none' }
  }
  const target = String(targetId || '').trim()
  if (!target) throw new Error('friendship_not_found')
  const tPhone = normalizePhone(target)
  const r = await pool.query(
    `DELETE FROM friendships
     WHERE (from_phone=$1 AND (to_id=$2 OR to_id=$3))
        OR (from_phone=$2 AND (to_id=$1 OR to_id=$4))
        OR (from_phone=$3 AND (to_id=$1 OR to_id=$4))
     RETURNING id`,
    [phone, target, tPhone || target, phoneKey(phone)],
  )
  if (!r.rowCount) throw new Error('friendship_not_found')
  return { state: 'none' }
}

export async function phoneForTarget(targetId) {
  const peer = await resolvePeer(targetId)
  if (!peer || peer.kind === 'map') return null
  return normalizePhone(peer.targetId) || normalizePhone(peer.id)
}

export async function areFriends(rawPhone, targetId) {
  const phone = normalizePhone(rawPhone)
  const target = String(targetId || '').trim()
  if (!phone || !target) return false
  const peer = await resolvePeer(target)
  if (!peer) return false
  const edge = await findEdge(phone, peer.targetId || target)
  return Boolean(edge && edge.status === 'accepted')
}

export async function participantKey(targetId) {
  const peer = await resolvePeer(targetId)
  if (!peer) return null
  if (peer.kind === 'phone') return normalizePhone(peer.targetId) || normalizePhone(peer.id)
  return String(peer.targetId || peer.id || '').trim() || null
}

export async function displayNameForPhone(rawPhone) {
  const profile = await profileByPhone(rawPhone)
  return profile?.displayName || 'A Chkela student'
}

export async function recordProfileView({ viewerPhone: rawViewer, targetId }) {
  const viewerPhone = normalizePhone(rawViewer)
  const target = String(targetId || '').trim()
  if (!viewerPhone) throw new Error('phone_required')
  if (!target) throw new Error('target_required')
  const targetPhone = await phoneForTarget(target)
  if (!targetPhone) return { notified: false, reason: 'no_target_phone' }
  if (targetPhone === viewerPhone) return { notified: false, reason: 'self' }

  const cooldownMs = 30 * 60 * 1000
  const now = Date.now()
  const existing = await pool.query(
    'SELECT viewed_at FROM profile_views WHERE viewer_phone=$1 AND target_phone=$2',
    [viewerPhone, targetPhone],
  )
  if (existing.rows[0]) {
    const last = new Date(existing.rows[0].viewed_at).getTime()
    if (now - last < cooldownMs) {
      return {
        notified: false,
        reason: 'rate_limited',
        targetPhone,
        viewerName: await displayNameForPhone(viewerPhone),
      }
    }
  }
  await pool.query(
    `INSERT INTO profile_views (viewer_phone, target_phone, viewed_at)
     VALUES ($1,$2,NOW())
     ON CONFLICT (viewer_phone, target_phone) DO UPDATE SET viewed_at=NOW()`,
    [viewerPhone, targetPhone],
  )
  return {
    notified: true,
    targetPhone,
    viewerName: await displayNameForPhone(viewerPhone),
  }
}

