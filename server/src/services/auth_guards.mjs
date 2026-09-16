import {
  bearerToken,
  httpError,
  verifyAdminToken,
  verifyUserToken,
} from '../services/tokens.mjs'
import { normalizePhone } from '../services/friends.mjs'

export async function requireUser(req) {
  const token = bearerToken(req)
  if (!token) throw httpError('Sign in required', 401)
  try {
    const session = await verifyUserToken(token)
    req.user = session
    return session
  } catch (error) {
    if (error?.statusCode) throw error
    throw httpError('Invalid or expired session', 401)
  }
}

export async function requireAdmin(req) {
  const token = bearerToken(req)
  if (!token) throw httpError('Admin sign in required', 401)
  try {
    const session = await verifyAdminToken(token)
    req.admin = session
    return session
  } catch (error) {
    if (error?.statusCode) throw error
    throw httpError('Invalid or expired admin session', 401)
  }
}

/** Session phone wins; reject body/query phone mismatch. */
export function phoneFromSession(req, bodyPhone) {
  const sessionPhone = req.user?.phone
  if (!sessionPhone) throw httpError('Sign in required', 401)
  const requested = normalizePhone(bodyPhone)
  if (requested && requested !== sessionPhone) {
    throw httpError('Phone does not match session', 403)
  }
  return sessionPhone
}
