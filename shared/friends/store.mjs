import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'

/** Demo map peers that can be friended without a real phone account. */
export const MAP_PEER_CATALOG = {
  'hanna-b': {
    id: 'hanna-b',
    name: 'Hanna B.',
    initials: 'HB',
    grade: 'Grade 10',
    school: 'Bole Secondary School',
    subjects: ['Mathematics', 'Physics'],
    isMapPeer: true,
  },
  'daniel-m': {
    id: 'daniel-m',
    name: 'Daniel M.',
    initials: 'DM',
    grade: 'Grade 11',
    school: 'St. Joseph School',
    subjects: ['Biology', 'Chemistry'],
    isMapPeer: true,
  },
  'meron-a': {
    id: 'meron-a',
    name: 'Meron A.',
    initials: 'MA',
    grade: 'Grade 12',
    school: 'Addis Ababa Secondary School',
    subjects: ['Mathematics', 'English'],
    isMapPeer: true,
  },
  'yosef-k': {
    id: 'yosef-k',
    name: 'Yosef K.',
    initials: 'YK',
    grade: 'Grade 11',
    school: 'Lideta Secondary School',
    subjects: ['Physics', 'Mathematics'],
    isMapPeer: true,
  },
  'tigist-h': {
    id: 'tigist-h',
    name: 'Tigist H.',
    initials: 'TH',
    grade: 'Grade 9',
    school: 'Kazanchis Academy',
    subjects: ['Mathematics', 'English'],
    isMapPeer: true,
  },
  'abenezer-l': {
    id: 'abenezer-l',
    name: 'Abenezer L.',
    initials: 'AL',
    grade: 'Grade 12',
    school: 'Menelik II School',
    subjects: ['Chemistry', 'Biology'],
    isMapPeer: true,
  },
  'ruth-n': {
    id: 'ruth-n',
    name: 'Ruth N.',
    initials: 'RN',
    grade: 'Grade 10',
    school: 'International Community School',
    subjects: ['English', 'History'],
    isMapPeer: true,
  },
  'yonas-alem': {
    id: 'yonas-alem',
    name: 'Yonas Alem',
    initials: 'YA',
    grade: 'Grade 12',
    school: 'Addis Ababa Secondary School',
    subjects: ['Mathematics', 'Physics'],
    isMapPeer: true,
  },
  'dawit-girma': {
    id: 'dawit-girma',
    name: 'Dawit G.',
    initials: 'DG',
    grade: 'Grade 12',
    school: 'Addis Ababa Secondary School',
    subjects: ['Mathematics', 'Physics'],
    isMapPeer: true,
  },
  'sara-bek': {
    id: 'sara-bek',
    name: 'Sara Bekele',
    initials: 'SB',
    grade: 'Grade 11',
    school: 'Hawassa Secondary School',
    subjects: ['Physics', 'Chemistry'],
    isMapPeer: true,
  },
}

const EMPTY = { profiles: {}, friendships: [], profileViews: {} }

export function createFriendsStore(filePath) {
  ensureFile(filePath)

  function read() {
    try {
      const raw = readFileSync(filePath, 'utf8')
      const parsed = JSON.parse(raw)
      return {
        profiles:
          parsed.profiles && typeof parsed.profiles === 'object'
            ? parsed.profiles
            : {},
        friendships: Array.isArray(parsed.friendships) ? parsed.friendships : [],
        profileViews:
          parsed.profileViews && typeof parsed.profileViews === 'object'
            ? parsed.profileViews
            : {},
      }
    } catch {
      return { profiles: {}, friendships: [], profileViews: {} }
    }
  }

  function write(data) {
    writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8')
  }

  function upsertProfile(body) {
    const phone = normalizePhone(body.phone)
    if (!phone) throw new Error('phone_required')
    const data = read()
    const prev = data.profiles[phone] || {}
    let mapId = String(body.mapId || prev.mapId || '').trim()
    // Shared demo pin id must not be every real user's mapId.
    if (!mapId || mapId === 'selam-tadesse' || mapId === 'me') {
      mapId = phoneKey(phone)
    }
    const profile = {
      ...prev,
      phone,
      mapId,
      displayName: String(body.displayName || prev.displayName || '').trim(),
      school: String(body.school || prev.school || '').trim(),
      bio: String(body.bio || prev.bio || '').trim(),
      tagline: String(body.tagline || prev.tagline || '').trim(),
      grade: String(body.grade || prev.grade || '').trim(),
      cityId: String(body.cityId || prev.cityId || '').trim(),
      subjects: Array.isArray(body.subjects)
        ? body.subjects.map((s) => String(s)).filter(Boolean).slice(0, 4)
        : prev.subjects || [],
      moodEmoji: String(body.moodEmoji || prev.moodEmoji || '').trim(),
      moodLabel: String(body.moodLabel || prev.moodLabel || '').trim(),
      updatedAt: new Date().toISOString(),
    }
    data.profiles[phone] = profile
    write(data)
    return profile
  }

  function profileByPhone(phone) {
    const key = normalizePhone(phone)
    if (!key) return null
    return read().profiles[key] || null
  }

  function profileByMapId(mapId) {
    const id = String(mapId || '').trim()
    if (!id) return null
    if (MAP_PEER_CATALOG[id]) return { ...MAP_PEER_CATALOG[id], mapId: id }
    const data = read()
    for (const profile of Object.values(data.profiles)) {
      if (profile.mapId === id || profile.phone === id) return profile
    }
    return null
  }

  function resolvePeer(targetId) {
    const id = String(targetId || '').trim()
    if (!id) return null
    if (MAP_PEER_CATALOG[id]) {
      return { ...MAP_PEER_CATALOG[id], targetId: id, kind: 'map' }
    }
    const asPhone = normalizePhone(id)
    if (asPhone) {
      const profile = profileByPhone(asPhone)
      if (!profile) {
        return {
          targetId: asPhone,
          kind: 'phone',
          id: asPhone,
          name: asPhone,
          initials: '?',
          grade: '',
          school: '',
          subjects: [],
        }
      }
      return {
        targetId: asPhone,
        kind: 'phone',
        // Prefer phone as the stable chat/routing id (mapId is not unique).
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
    const byMap = profileByMapId(id)
    if (byMap) {
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
    return null
  }

  function isMapPeer(targetId) {
    return Boolean(MAP_PEER_CATALOG[String(targetId || '').trim()])
  }

  function listForPhone(rawPhone) {
    const phone = normalizePhone(rawPhone)
    if (!phone) throw new Error('phone_required')
    const data = read()
    const friends = []
    const incoming = []
    const outgoing = []

    for (const row of data.friendships) {
      const a = normalizePhone(row.fromPhone)
      const b = String(row.toId || '').trim()
      const bPhone = normalizePhone(b)
      const involves =
        a === phone || b === phone || bPhone === phone || row.toId === phone
      if (!involves) continue

      const iAmFrom = a === phone
      const peerId = iAmFrom ? row.toId : row.fromPhone
      const peer = resolvePeer(peerId) || {
        targetId: peerId,
        id: peerId,
        name: String(peerId),
        initials: '?',
        grade: '',
        school: '',
        subjects: [],
        kind: 'unknown',
      }

      const item = {
        friendshipId: row.id,
        status: row.status,
        peer,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      }

      if (row.status === 'accepted') {
        friends.push(item)
      } else if (row.status === 'pending') {
        if (iAmFrom) outgoing.push(item)
        else incoming.push(item)
      }
    }

    return { phone, friends, incoming, outgoing }
  }

  function findEdge(data, fromPhone, toId) {
    const from = normalizePhone(fromPhone)
    const to = String(toId || '').trim()
    const toPhone = normalizePhone(to)
    return data.friendships.find((row) => {
      const a = normalizePhone(row.fromPhone)
      const b = String(row.toId || '').trim()
      const bPhone = normalizePhone(b)
      const sameDirection = a === from && (b === to || bPhone === toPhone)
      const reverse =
        a === (toPhone || to) &&
        (b === from || normalizePhone(b) === from)
      return sameDirection || reverse
    })
  }

  function request({ phone: rawPhone, targetId }) {
    const phone = normalizePhone(rawPhone)
    const target = String(targetId || '').trim()
    if (!phone) throw new Error('phone_required')
    if (!target) throw new Error('target_required')
    if (normalizePhone(target) === phone || target === phone) {
      throw new Error('cannot_friend_self')
    }

    const peer = resolvePeer(target)
    if (!peer) throw new Error('peer_not_found')

    const data = read()
    const existing = findEdge(data, phone, peer.targetId || target)
    const now = new Date().toISOString()

    if (existing) {
      if (existing.status === 'accepted') {
        return { friendship: existing, state: 'friends' }
      }
      // Incoming pending: treat request as accept.
      if (
        existing.status === 'pending' &&
        normalizePhone(existing.fromPhone) !== phone
      ) {
        existing.status = 'accepted'
        existing.updatedAt = now
        write(data)
        return { friendship: existing, state: 'friends' }
      }
      if (existing.status === 'pending') {
        return { friendship: existing, state: 'outgoing' }
      }
    }

    const autoAccept = isMapPeer(target) || isMapPeer(peer.id)
    const friendship = {
      id: `f_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 7)}`,
      fromPhone: phone,
      toId: peer.targetId || target,
      status: autoAccept ? 'accepted' : 'pending',
      createdAt: now,
      updatedAt: now,
    }
    data.friendships.push(friendship)
    write(data)
    return {
      friendship,
      state: autoAccept ? 'friends' : 'outgoing',
    }
  }

  function respond({ phone: rawPhone, friendshipId, action }) {
    const phone = normalizePhone(rawPhone)
    if (!phone) throw new Error('phone_required')
    const id = String(friendshipId || '').trim()
    const act = String(action || '').trim().toLowerCase()
    if (!id) throw new Error('friendship_required')
    if (act !== 'accept' && act !== 'decline') {
      throw new Error('action_must_be_accept_or_decline')
    }

    const data = read()
    const row = data.friendships.find((f) => f.id === id)
    if (!row) throw new Error('friendship_not_found')

    const toPhone = normalizePhone(row.toId)
    const iAmTarget =
      toPhone === phone ||
      String(row.toId) === phone ||
      (profileByPhone(phone)?.mapId &&
        profileByPhone(phone).mapId === String(row.toId))
    if (!iAmTarget) throw new Error('not_request_recipient')

    if (act === 'decline') {
      data.friendships = data.friendships.filter((f) => f.id !== id)
      write(data)
      return { state: 'none' }
    }

    row.status = 'accepted'
    row.updatedAt = new Date().toISOString()
    write(data)
    return { friendship: row, state: 'friends' }
  }

  function remove({ phone: rawPhone, targetId, friendshipId }) {
    const phone = normalizePhone(rawPhone)
    if (!phone) throw new Error('phone_required')
    const data = read()
    const before = data.friendships.length

    data.friendships = data.friendships.filter((row) => {
      if (friendshipId && row.id === friendshipId) {
        const a = normalizePhone(row.fromPhone)
        const bPhone = normalizePhone(row.toId)
        const involves = a === phone || bPhone === phone || row.toId === phone
        return !involves
      }
      if (!targetId) return true
      const target = String(targetId).trim()
      const a = normalizePhone(row.fromPhone)
      const b = String(row.toId || '').trim()
      const bPhone = normalizePhone(b)
      const involvesMe = a === phone || bPhone === phone || b === phone
      if (!involvesMe) return true
      const peerIsTarget =
        b === target ||
        bPhone === normalizePhone(target) ||
        a === normalizePhone(target) ||
        a === target
      return !peerIsTarget
    })

    if (data.friendships.length === before) {
      throw new Error('friendship_not_found')
    }
    write(data)
    return { state: 'none' }
  }

  function phoneForTarget(targetId) {
    const peer = resolvePeer(targetId)
    if (!peer) return null
    if (peer.kind === 'map') return null
    return normalizePhone(peer.targetId) || normalizePhone(peer.id)
  }

  /** True when phone and target share an accepted friendship edge. */
  function areFriends(rawPhone, targetId) {
    const phone = normalizePhone(rawPhone)
    const target = String(targetId || '').trim()
    if (!phone || !target) return false
    const peer = resolvePeer(target)
    if (!peer) return false
    const data = read()
    const edge = findEdge(data, phone, peer.targetId || target)
    return Boolean(edge && edge.status === 'accepted')
  }

  /** Stable chat participant key: E.164 phone, or map peer slug. */
  function participantKey(targetId) {
    const peer = resolvePeer(targetId)
    if (!peer) return null
    if (peer.kind === 'phone') {
      return normalizePhone(peer.targetId) || normalizePhone(peer.id)
    }
    return String(peer.targetId || peer.id || '').trim() || null
  }

  function displayNameForPhone(rawPhone) {
    const profile = profileByPhone(rawPhone)
    if (profile?.displayName) return profile.displayName
    return 'A Chkela student'
  }

  /** Notify-worthy profile view. Rate-limited per viewer→target. */
  function recordProfileView({ viewerPhone: rawViewer, targetId }) {
    const viewerPhone = normalizePhone(rawViewer)
    const target = String(targetId || '').trim()
    if (!viewerPhone) throw new Error('phone_required')
    if (!target) throw new Error('target_required')

    const targetPhone = phoneForTarget(target)
    if (!targetPhone) {
      return { notified: false, reason: 'no_target_phone' }
    }
    if (targetPhone === viewerPhone) {
      return { notified: false, reason: 'self' }
    }

    const data = read()
    if (!data.profileViews || typeof data.profileViews !== 'object') {
      data.profileViews = {}
    }
    const key = `${viewerPhone}→${targetPhone}`
    const now = Date.now()
    const last = Number(data.profileViews[key] || 0)
    const cooldownMs = 30 * 60 * 1000
    if (now - last < cooldownMs) {
      return {
        notified: false,
        reason: 'rate_limited',
        targetPhone,
        viewerName: displayNameForPhone(viewerPhone),
      }
    }
    data.profileViews[key] = now
    write(data)

    return {
      notified: true,
      targetPhone,
      viewerName: displayNameForPhone(viewerPhone),
    }
  }

  return {
    upsertProfile,
    profileByPhone,
    listForPhone,
    request,
    respond,
    remove,
    phoneForTarget,
    displayNameForPhone,
    recordProfileView,
    resolvePeer,
    areFriends,
    participantKey,
    isMapPeer,
    normalizePhone,
  }
}

export function normalizePhone(value) {
  const digits = String(value || '').replace(/[^\d+]/g, '').trim()
  if (!digits) return null
  const compact = digits.replace(/(?!^)\+/g, '')
  const onlyDigits = compact.replace(/\D/g, '')
  if (onlyDigits.length < 9 || onlyDigits.length > 13) return null
  if (compact.startsWith('+')) return `+${onlyDigits}`
  if (onlyDigits.startsWith('251') && onlyDigits.length >= 12) {
    return `+${onlyDigits}`
  }
  if (onlyDigits.startsWith('0') && onlyDigits.length === 10) {
    return `+251${onlyDigits.slice(1)}`
  }
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
  if (parts.length === 1) {
    return parts[0].slice(0, 2).toUpperCase()
  }
  return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase()
}

function ensureFile(filePath) {
  const dir = dirname(filePath)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  if (!existsSync(filePath)) {
    writeFileSync(filePath, `${JSON.stringify(EMPTY, null, 2)}\n`, 'utf8')
  }
}
