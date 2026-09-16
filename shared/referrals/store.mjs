import { createHash } from 'node:crypto'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'

/** Signup CP the referrer earns when an invitee finishes onboarding. */
export const REFERRER_POINTS = 100
/** Signup CP the invitee earns when redeeming a valid code. */
export const INVITEE_POINTS = 50
/** Invitee discount on subscription purchase. */
export const INVITEE_PURCHASE_DISCOUNT_PERCENT = 10
/** Referrer commission on invitee purchase amount, paid in CP (not ETB). */
export const REFERRER_PURCHASE_CP_PERCENT = 20
export const REFERRAL_LINK_BASE = 'https://www.chkela.com/?ref='

const EMPTY = { referrals: [], pointBalances: {} }
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'

export function createReferralStore(filePath) {
  ensureFile(filePath)

  function read() {
    try {
      const raw = readFileSync(filePath, 'utf8')
      const parsed = JSON.parse(raw)
      return {
        referrals: Array.isArray(parsed.referrals) ? parsed.referrals : [],
        pointBalances:
          parsed.pointBalances && typeof parsed.pointBalances === 'object'
            ? parsed.pointBalances
            : {},
      }
    } catch {
      return { referrals: [], pointBalances: {} }
    }
  }

  function write(data) {
    writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8')
  }

  function addCp(data, phone, amount) {
    if (!phone || !amount) return
    const current = Number(data.pointBalances[phone] || 0)
    data.pointBalances[phone] = current + amount
  }

  function list() {
    return read().referrals.sort((a, b) =>
      b.createdAt.localeCompare(a.createdAt),
    )
  }

  function listBalances() {
    const balances = read().pointBalances || {}
    return Object.entries(balances)
      .map(([phone, cp]) => ({
        phone,
        points: Number(cp) || 0,
        cp: Number(cp) || 0,
      }))
      .sort((a, b) => b.cp - a.cp || a.phone.localeCompare(b.phone))
  }

  function findInviteeRedemption(data, inviteePhone) {
    for (let i = 0; i < data.referrals.length; i += 1) {
      const entry = data.referrals[i]
      const redemptions = entry.redemptions || []
      const rIndex = redemptions.findIndex((r) => r.inviteePhone === inviteePhone)
      if (rIndex >= 0) {
        return { entry, entryIndex: i, redemption: redemptions[rIndex], rIndex }
      }
    }
    return null
  }

  function getOrCreate(rawPhone) {
    const phone = normalizePhone(rawPhone)
    if (!phone) throw new Error('Valid phone is required')

    const data = read()
    const existing = data.referrals.find((item) => item.referrerPhone === phone)
    if (existing) {
      if (typeof existing.pointsEarned !== 'number') existing.pointsEarned = 0
      if (typeof existing.purchaseCpEarned !== 'number') {
        existing.purchaseCpEarned = 0
      }
      return existing
    }

    const entry = {
      id: `r_${Date.now().toString(36)}`,
      code: codeFromPhone(phone),
      referrerPhone: phone,
      createdAt: new Date().toISOString(),
      creditDaysEarned: 0,
      pointsEarned: 0,
      purchaseCpEarned: 0,
      redemptions: [],
    }

    let attempts = 0
    while (data.referrals.some((item) => item.code === entry.code)) {
      attempts += 1
      entry.code = codeFromPhone(`${phone}:${attempts}`)
    }

    data.referrals.push(entry)
    write(data)
    return entry
  }

  function me(rawPhone) {
    const phone = normalizePhone(rawPhone)
    const entry = getOrCreate(rawPhone)
    const data = read()
    const cpBalance = phone ? Number(data.pointBalances[phone] || 0) : 0
    return {
      code: entry.code,
      link: `${REFERRAL_LINK_BASE}${entry.code}`,
      referrerPhone: entry.referrerPhone,
      inviteCount: entry.redemptions.length,
      creditDaysEarned: entry.creditDaysEarned || 0,
      pointsEarned: entry.pointsEarned || 0,
      purchaseCpEarned: entry.purchaseCpEarned || 0,
      cpBalance,
      pointsBalance: cpBalance,
      unlockDaysPerInvite: 0,
      pointsPerInvite: REFERRER_POINTS,
      inviteePointsPerRedeem: INVITEE_POINTS,
      inviteePurchaseDiscountPercent: INVITEE_PURCHASE_DISCOUNT_PERCENT,
      referrerPurchaseCpPercent: REFERRER_PURCHASE_CP_PERCENT,
    }
  }

  function discountFor(rawPhone) {
    const phone = normalizePhone(rawPhone)
    if (!phone) return { ok: false, error: 'missing_phone' }

    const found = findInviteeRedemption(read(), phone)
    if (!found) {
      return { ok: true, eligible: false, discountPercent: 0 }
    }

    return {
      ok: true,
      eligible: true,
      discountPercent:
        found.redemption.purchaseDiscountPercent ||
        INVITEE_PURCHASE_DISCOUNT_PERCENT,
      code: found.entry.code,
      referrerPhone: found.entry.referrerPhone,
    }
  }

  function redeem(rawCode, rawInviteePhone) {
    const code = normalizeCode(rawCode)
    if (!code) return { ok: false, error: 'invalid' }

    const inviteePhone = normalizePhone(rawInviteePhone)
    if (!inviteePhone) return { ok: false, error: 'missing_phone' }

    const data = read()
    const index = data.referrals.findIndex((item) => item.code === code)
    if (index < 0) return { ok: false, error: 'not_found' }

    const entry = data.referrals[index]
    if (entry.referrerPhone === inviteePhone) {
      return { ok: false, error: 'self_referral' }
    }

    const already = data.referrals.some((item) =>
      (item.redemptions || []).some((r) => r.inviteePhone === inviteePhone),
    )
    if (already) return { ok: false, error: 'already_redeemed' }

    const redemption = {
      inviteePhone,
      redeemedAt: new Date().toISOString(),
      unlockDays: 0,
      referrerPoints: REFERRER_POINTS,
      inviteePoints: INVITEE_POINTS,
      purchaseDiscountPercent: INVITEE_PURCHASE_DISCOUNT_PERCENT,
      purchases: [],
    }

    entry.redemptions = [...(entry.redemptions || []), redemption]
    // No free/credit days — rewards are CP + purchase discount only.
    entry.pointsEarned = (entry.pointsEarned || 0) + REFERRER_POINTS
    if (typeof entry.purchaseCpEarned !== 'number') entry.purchaseCpEarned = 0
    data.referrals[index] = entry

    addCp(data, entry.referrerPhone, REFERRER_POINTS)
    addCp(data, inviteePhone, INVITEE_POINTS)
    write(data)

    return {
      ok: true,
      code: entry.code,
      unlockDays: 0,
      referrerCreditDays: 0,
      referrerPoints: REFERRER_POINTS,
      inviteePoints: INVITEE_POINTS,
      purchaseDiscountPercent: INVITEE_PURCHASE_DISCOUNT_PERCENT,
    }
  }

  function recordPurchase(rawInviteePhone, rawAmountEtb) {
    const inviteePhone = normalizePhone(rawInviteePhone)
    if (!inviteePhone) return { ok: false, error: 'missing_phone' }

    const amountEtb = Math.round(Number(rawAmountEtb))
    if (!Number.isFinite(amountEtb) || amountEtb < 1) {
      return { ok: false, error: 'invalid_amount' }
    }

    const data = read()
    const found = findInviteeRedemption(data, inviteePhone)
    if (!found) return { ok: false, error: 'not_an_invitee' }

    const referrerCp = Math.round(
      (amountEtb * REFERRER_PURCHASE_CP_PERCENT) / 100,
    )
    const purchase = {
      amountEtb,
      referrerCp,
      purchasedAt: new Date().toISOString(),
    }

    const redemptions = [...(found.entry.redemptions || [])]
    const redemption = { ...redemptions[found.rIndex] }
    redemption.purchases = [...(redemption.purchases || []), purchase]
    redemptions[found.rIndex] = redemption

    const entry = { ...found.entry, redemptions }
    entry.purchaseCpEarned = (entry.purchaseCpEarned || 0) + referrerCp
    data.referrals[found.entryIndex] = entry

    addCp(data, entry.referrerPhone, referrerCp)
    write(data)

    return {
      ok: true,
      amountEtb,
      referrerCp,
      referrerPhone: entry.referrerPhone,
      code: entry.code,
    }
  }

  return {
    list,
    listBalances,
    getOrCreate,
    me,
    discountFor,
    redeem,
    recordPurchase,
  }
}

function ensureFile(filePath) {
  const dir = dirname(filePath)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  if (!existsSync(filePath)) {
    writeFileSync(filePath, `${JSON.stringify(EMPTY, null, 2)}\n`, 'utf8')
  }
}

/** Stable CHK-XXXXXX from phone last-9 digits (gift/battle alphabet). */
export function codeFromPhone(rawPhone) {
  const digits = String(rawPhone || '').replace(/\D/g, '').slice(-9)
  const seed = digits.length >= 9 ? digits : `000000000${digits}`.slice(-9)
  const hash = createHash('sha256').update(`chkela-ref:${seed}`).digest()
  let out = 'CHK-'
  for (let i = 0; i < 6; i += 1) {
    out += ALPHABET[hash[i] % ALPHABET.length]
  }
  return out
}

function normalizeCode(value) {
  return String(value || '')
    .trim()
    .toUpperCase()
    .replace(/\s+/g, '')
    .replace(/[^A-Z0-9-]/g, '')
}

function normalizePhone(value) {
  const digits = String(value || '').replace(/[^\d+]/g, '').trim()
  if (!digits) return null
  const compact = digits.replace(/(?!^)\+/g, '')
  const onlyDigits = compact.replace(/\D/g, '')
  if (onlyDigits.length < 9 || onlyDigits.length > 13) return null
  return compact
}
