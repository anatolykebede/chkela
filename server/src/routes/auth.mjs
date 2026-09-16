import { normalizePhone } from '../services/friends.mjs'
import {
  afroMessageConfigured,
  sendSecurityCode,
  verifySecurityCode,
} from '../services/afromessage.mjs'
import {
  deleteUserAccount,
  getUserByPhone,
  registerUserFromOtp,
  updateUserProfile,
} from '../services/users.mjs'
import { signUserToken, httpError } from '../services/tokens.mjs'
import {
  phoneFromSession,
  requireUser,
} from '../services/auth_guards.mjs'

/** phone -> { verificationId, sentAt } */
const pending = new Map()

const SEND_COOLDOWN_MS = 45_000
const OTP_TTL_MS = 5 * 60 * 1000

function isEthiopianMobile(phone) {
  return /^\+2519\d{8}$/.test(phone)
}

function pruneExpired() {
  const now = Date.now()
  for (const [phone, row] of pending.entries()) {
    if (now - row.sentAt > OTP_TTL_MS) pending.delete(phone)
  }
}

async function completeVerification(phone, mode) {
  const user = await registerUserFromOtp(phone)
  const token = await signUserToken(phone)
  return { ok: true, phone, verified: true, mode, user, token }
}

export default async function authRoutes(app) {
  app.post(
    '/api/auth/otp/send',
    {
      config: {
        rateLimit: { max: 5, timeWindow: '1 minute' },
      },
    },
    async (req) => {
      pruneExpired()
      const phone = normalizePhone(req.body?.phone)
      if (!phone || !isEthiopianMobile(phone)) {
        throw httpError('Enter a valid Ethiopian mobile number')
      }

      const existing = pending.get(phone)
      if (existing && Date.now() - existing.sentAt < SEND_COOLDOWN_MS) {
        const waitSec = Math.ceil(
          (SEND_COOLDOWN_MS - (Date.now() - existing.sentAt)) / 1000,
        )
        throw httpError(`Wait ${waitSec}s before requesting another code`)
      }

      // Local/dev: skip AfroMessage so web/device testing works without verified contacts.
      if (process.env.AUTH_OTP_DEV_BYPASS === '1') {
        pending.set(phone, { verificationId: 'dev', sentAt: Date.now() })
        return { ok: true, phone, mode: 'dev' }
      }

      if (!afroMessageConfigured()) {
        throw httpError('SMS provider is not configured', 503)
      }

      try {
        const result = await sendSecurityCode({ to: phone })
        pending.set(phone, {
          verificationId: result.verificationId,
          sentAt: Date.now(),
        })
        return { ok: true, phone, mode: 'sms' }
      } catch (error) {
        const raw =
          error instanceof Error ? error.message : 'Could not send SMS code'
        if (/unverified contact/i.test(raw)) {
          throw httpError(
            'This number is not verified for SMS yet. In AfroMessage (beta), open Contacts, find the number, and tap Verify. Then try again.',
            502,
          )
        }
        throw httpError(raw, 502)
      }
    },
  )

  app.post(
    '/api/auth/otp/verify',
    {
      config: {
        rateLimit: { max: 10, timeWindow: '1 minute' },
      },
    },
    async (req) => {
      pruneExpired()
      const phone = normalizePhone(req.body?.phone)
      const code = String(req.body?.code || '').trim()

      if (!phone || !isEthiopianMobile(phone)) {
        throw httpError('Enter a valid Ethiopian mobile number')
      }
      if (!/^\d{4}$/.test(code)) {
        throw httpError('Enter the 4-digit code')
      }

      const row = pending.get(phone)

      if (process.env.AUTH_OTP_DEV_BYPASS === '1') {
        if (code === (process.env.AUTH_OTP_DEV_CODE || '1234')) {
          pending.delete(phone)
          return completeVerification(phone, 'dev')
        }
        throw httpError('Incorrect code. Try again.')
      }

      if (!afroMessageConfigured()) {
        throw httpError('SMS provider is not configured', 503)
      }

      if (!row) {
        throw httpError('Request a code first')
      }

      try {
        await verifySecurityCode({
          to: phone,
          code,
          verificationId: row.verificationId,
        })
      } catch (error) {
        const raw =
          error instanceof Error ? error.message : 'Incorrect code. Try again.'
        const lower = String(raw).toLowerCase()
        if (
          /invalid|expire|mismatch|wrong|code|bad request|unauthorized|forbidden|not found|failed|afromessage_http_4/i.test(
            lower,
          )
        ) {
          throw httpError('Incorrect code. Try again.')
        }
        throw httpError('Could not verify code right now. Try again.', 502)
      }

      pending.delete(phone)
      return completeVerification(phone, 'sms')
    },
  )

  app.get('/api/auth/me', async (req) => {
    await requireUser(req)
    const phone = phoneFromSession(req, req.query?.phone)
    const user = await getUserByPhone(phone)
    return { ok: true, user }
  })

  app.post('/api/auth/profile', async (req) => {
    await requireUser(req)
    const body = req.body || {}
    const phone = phoneFromSession(req, body.phone)

    const user = await updateUserProfile({
      phone,
      displayName: body.displayName ?? body.name,
      grade: body.grade,
      birthdate: body.birthdate,
      interests: body.interests,
      onboardingComplete: body.onboardingComplete,
    })

    return { ok: true, user }
  })

  app.post('/api/auth/account/delete', async (req) => {
    await requireUser(req)
    const phone = phoneFromSession(req, req.body?.phone)
    const result = await deleteUserAccount(phone)
    return { ok: true, deleted: true, alreadyDeleted: result.alreadyDeleted }
  })
}
