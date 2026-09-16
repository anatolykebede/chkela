const BASE = 'https://api.afromessage.com/api'

function token() {
  return String(process.env.AFROMESSAGE_TOKEN || '').trim()
}

function identifier() {
  return String(process.env.AFROMESSAGE_IDENTIFIER || '').trim()
}

function sender() {
  return String(process.env.AFROMESSAGE_SENDER || '').trim()
}

export function afroMessageConfigured() {
  return token().length > 0
}

async function afroGet(path, query) {
  const auth = token()
  if (!auth) throw new Error('afromessage_not_configured')

  const url = new URL(`${BASE}${path}`)
  for (const [key, value] of Object.entries(query)) {
    if (value === undefined || value === null || value === '') continue
    url.searchParams.set(key, String(value))
  }

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${auth}`,
      Accept: 'application/json',
    },
  })

  const raw = await response.text()
  let data
  try {
    data = raw ? JSON.parse(raw) : {}
  } catch {
    throw new Error(`afromessage_bad_response_${response.status}`)
  }

  if (response.status === 401) {
    throw new Error(
      'AfroMessage auth failed. Check AFROMESSAGE_TOKEN / identifier.',
    )
  }

  if (!response.ok) {
    const err =
      data?.response?.errors?.[0] ||
      data?.response?.error ||
      `afromessage_http_${response.status}`
    throw new Error(String(err))
  }

  return data
}

/**
 * Send a numeric OTP via AfroMessage /challenge.
 * @returns {{ verificationId: string|null, to: string }}
 */
export async function sendSecurityCode({
  to,
  len = 4,
  ttl = 300,
  prefix = 'Your Chkela code is',
}) {
  const query = {
    to,
    len,
    t: 0,
    ttl,
    pr: prefix,
    sb: 1,
    from: identifier() || undefined,
    sender: sender() || undefined,
  }

  const data = await afroGet('/challenge', query)
  if (data.acknowledge !== 'success') {
    const err =
      data?.response?.errors?.[0] ||
      data?.response?.error ||
      'afromessage_challenge_failed'
    throw new Error(String(err))
  }

  const body = data.response || {}
  return {
    verificationId: body.verificationId || body.verification_id || null,
    to: body.to || to,
    messageId: body.message_id || null,
  }
}

/**
 * Verify an OTP via AfroMessage /verify.
 */
export async function verifySecurityCode({ to, code, verificationId }) {
  const query = {
    to,
    code,
    vc: verificationId || undefined,
  }

  const data = await afroGet('/verify', query)
  if (data.acknowledge !== 'success') {
    const err =
      data?.response?.errors?.[0] ||
      data?.response?.error ||
      'invalid_code'
    throw new Error(String(err))
  }

  return { ok: true, response: data.response || {} }
}
