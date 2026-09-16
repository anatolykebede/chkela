import { phoneKey as studentPhoneKey } from '../students/store.mjs'
import { phoneKey as subPhoneKey } from './store.mjs'
import { readFileSync, existsSync } from 'node:fs'

function keyOf(phone) {
  return subPhoneKey(phone) || studentPhoneKey(phone)
}

function uniquePhones(phones) {
  const seen = new Set()
  const out = []
  for (const phone of phones) {
    const key = keyOf(phone)
    if (!key || seen.has(key)) continue
    seen.add(key)
    out.push(phone)
  }
  return out
}

function tokensByAudience(notifications, predicate) {
  return notifications.listTokens().filter(predicate)
}

function phonesFromTokens(tokens) {
  return uniquePhones(tokens.map((t) => t.phone).filter(Boolean))
}

/**
 * Resolve push audiences from existing Chkela stores.
 * Always returns devices that currently have an FCM token (unless noted).
 */
export function createAudienceResolver({
  notifications,
  students,
  subscriptions,
  giftCodesFile,
  friendsFile,
}) {
  function giftClaimerKeys() {
    if (!giftCodesFile || !existsSync(giftCodesFile)) return new Set()
    try {
      const raw = JSON.parse(readFileSync(giftCodesFile, 'utf8'))
      const codes = Array.isArray(raw.codes) ? raw.codes : []
      const keys = new Set()
      for (const code of codes) {
        if (!code.claimedAt || !code.claimedBy) continue
        const key = keyOf(code.claimedBy)
        if (key) keys.add(key)
      }
      return keys
    } catch {
      return new Set()
    }
  }

  function mapProfileKeys() {
    if (!friendsFile || !existsSync(friendsFile)) return new Set()
    try {
      const raw = JSON.parse(readFileSync(friendsFile, 'utf8'))
      const profiles = raw.profiles && typeof raw.profiles === 'object'
        ? raw.profiles
        : {}
      const keys = new Set()
      for (const phone of Object.keys(profiles)) {
        const key = keyOf(phone)
        if (key) keys.add(key)
      }
      return keys
    } catch {
      return new Set()
    }
  }

  function studentKeys(status) {
    const keys = new Set()
    for (const student of students.list()) {
      if (status && student.status !== status) continue
      const key = keyOf(student.phone)
      if (key) keys.add(key)
    }
    return keys
  }

  const definitions = [
    {
      id: 'all',
      label: 'All registered devices',
      description:
        'Every phone that opened Chkela and allowed notifications (FCM token)',
    },
    {
      id: 'unpaid',
      label: 'Unpaid / free users',
      description: 'Devices with no active paid subscription',
    },
    {
      id: 'paid',
      label: 'Paid subscribers',
      description: 'Devices with an active subscription on file',
    },
    {
      id: 'ios',
      label: 'iOS devices',
      description: 'Registered Apple devices only',
    },
    {
      id: 'android',
      label: 'Android devices',
      description: 'Registered Android devices only',
    },
    {
      id: 'active_students',
      label: 'Active allowlisted students',
      description: 'Active students who also have the app installed',
    },
    {
      id: 'inactive_students',
      label: 'Inactive students',
      description: 'Inactive students who still have a device token',
    },
    {
      id: 'map_profiles',
      label: 'Map profile users',
      description: 'People who completed a map profile',
    },
    {
      id: 'gift_claimers',
      label: 'Gift code claimers',
      description: 'Users who claimed a gift code',
    },
    {
      id: 'never_gift',
      label: 'Never claimed a gift',
      description: 'Active students with devices who never claimed',
    },
  ]

  function resolve(audienceId) {
    const id = String(audienceId || 'all').trim() || 'all'
    const tokens = notifications.listTokens()
    const paid = (phone) => subscriptions.isPaid(phone)
    const activeKeys = studentKeys('active')
    const inactiveKeys = studentKeys('inactive')
    const claimers = giftClaimerKeys()
    const mapKeys = mapProfileKeys()

    let matched = tokens
    switch (id) {
      case 'all':
        matched = tokens
        break
      case 'unpaid':
        matched = tokens.filter((t) => t.phone && !paid(t.phone))
        break
      case 'paid':
        matched = tokens.filter((t) => t.phone && paid(t.phone))
        break
      case 'ios':
        matched = tokens.filter(
          (t) => String(t.platform || '').toLowerCase() === 'ios',
        )
        break
      case 'android':
        matched = tokens.filter(
          (t) => String(t.platform || '').toLowerCase() === 'android',
        )
        break
      case 'active_students':
        matched = tokens.filter(
          (t) => t.phone && activeKeys.has(keyOf(t.phone)),
        )
        break
      case 'inactive_students':
        matched = tokens.filter(
          (t) => t.phone && inactiveKeys.has(keyOf(t.phone)),
        )
        break
      case 'map_profiles':
        matched = tokens.filter(
          (t) => t.phone && mapKeys.has(keyOf(t.phone)),
        )
        break
      case 'gift_claimers':
        matched = tokens.filter(
          (t) => t.phone && claimers.has(keyOf(t.phone)),
        )
        break
      case 'never_gift':
        matched = tokens.filter((t) => {
          if (!t.phone) return false
          const key = keyOf(t.phone)
          return activeKeys.has(key) && !claimers.has(key)
        })
        break
      default:
        throw new Error(`Unknown audience: ${id}`)
    }

    return {
      id,
      deviceCount: matched.length,
      phones: phonesFromTokens(matched),
      tokens: matched.map((t) => t.token),
    }
  }

  function listWithCounts() {
    return definitions.map((def) => {
      try {
        const resolved = resolve(def.id)
        return {
          ...def,
          deviceCount: resolved.deviceCount,
          phoneCount: resolved.phones.length,
        }
      } catch {
        return { ...def, deviceCount: 0, phoneCount: 0 }
      }
    })
  }

  return { definitions, resolve, listWithCounts }
}
