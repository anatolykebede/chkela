import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'

const EMPTY = { tokens: [], messages: [] }
// Resolve deps from dashboard/node_modules (this file lives in shared/).
const require = createRequire(
  resolve(dirname(fileURLToPath(import.meta.url)), '../../dashboard/package.json'),
)

export function createNotificationsStore(filePath, { serviceAccountPath } = {}) {
  ensureFile(filePath)
  let messaging = null
  let initError = null

  function getMessaging() {
    if (messaging) return messaging
    if (initError) return null
    const accountFile =
      serviceAccountPath ||
      resolve(dirname(filePath), 'serviceAccount.json')
    if (!existsSync(accountFile)) {
      initError = 'No serviceAccount.json'
      return null
    }
    try {
      const { initializeApp, getApps, cert } = require('firebase-admin/app')
      const { getMessaging: getFcm } = require('firebase-admin/messaging')
      if (!getApps().length) {
        const serviceAccount = JSON.parse(readFileSync(accountFile, 'utf8'))
        initializeApp({
          credential: cert(serviceAccount),
        })
      }
      messaging = getFcm()
      return messaging
    } catch (error) {
      initError =
        error instanceof Error ? error.message : 'FCM admin init failed'
      console.error('FCM admin init failed:', error)
      return null
    }
  }

  function read() {
    try {
      const raw = readFileSync(filePath, 'utf8')
      const parsed = JSON.parse(raw)
      return {
        tokens: Array.isArray(parsed.tokens) ? parsed.tokens : [],
        messages: Array.isArray(parsed.messages) ? parsed.messages : [],
      }
    } catch {
      return { tokens: [], messages: [] }
    }
  }

  function write(data) {
    writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8')
  }

  function listTokens() {
    return read().tokens.sort((a, b) =>
      (b.updatedAt || '').localeCompare(a.updatedAt || ''),
    )
  }

  function listMessages() {
    return read().messages.sort((a, b) =>
      b.createdAt.localeCompare(a.createdAt),
    )
  }

  function register({ token, phone, platform }) {
    const cleanToken = String(token || '').trim()
    if (!cleanToken) throw new Error('Token is required')

    const data = read()
    const index = data.tokens.findIndex((item) => item.token === cleanToken)
    const entry = {
      token: cleanToken,
      phone: normalizePhone(phone),
      platform: String(platform || 'unknown'),
      updatedAt: new Date().toISOString(),
      createdAt:
        index >= 0
          ? data.tokens[index].createdAt
          : new Date().toISOString(),
    }
    if (index >= 0) data.tokens[index] = entry
    else data.tokens.push(entry)
    write(data)
    return entry
  }

  async function send({ title, body, phone, phones, tokens: tokenList, topic, audience }) {
    const cleanTitle = String(title || '').trim()
    const cleanBody = String(body || '').trim()
    if (!cleanTitle || !cleanBody) {
      throw new Error('Title and body are required')
    }

    const data = read()
    const fcm = getMessaging()
    const audienceId = audience ? String(audience) : null
    const targetPhone = normalizePhone(phone)
    const phoneSet = new Set(
      (Array.isArray(phones) ? phones : [])
        .map((p) => normalizePhone(p))
        .filter(Boolean),
    )
    if (targetPhone) phoneSet.add(targetPhone)

    let tokens = data.tokens.map((t) => t.token)

    // "all" (and legacy empty target) = every registered device token.
    const broadcastAll =
      audienceId === 'all' ||
      (!audienceId && phoneSet.size === 0 && !topic && !tokenList)

    if (!broadcastAll) {
      if (Array.isArray(tokenList) && tokenList.length > 0) {
        const allow = new Set(tokenList.map((t) => String(t)))
        tokens = data.tokens
          .filter((t) => allow.has(t.token))
          .map((t) => t.token)
      } else if (phoneSet.size > 0) {
        tokens = data.tokens
          .filter((t) => t.phone && phoneSet.has(normalizePhone(t.phone)))
          .map((t) => t.token)
      }
    }

    // De-dupe while preserving order.
    tokens = [...new Set(tokens.filter(Boolean))]

    const messageRecord = {
      id: `n_${Date.now().toString(36)}`,
      title: cleanTitle,
      body: cleanBody,
      phone: broadcastAll ? null : targetPhone,
      phones: broadcastAll ? null : phoneSet.size > 0 ? [...phoneSet] : null,
      audience: audienceId || (broadcastAll ? 'all' : null),
      topic: topic ? String(topic) : null,
      createdAt: new Date().toISOString(),
      status: 'queued',
      successCount: 0,
      failureCount: 0,
      error: null,
      targetCount: tokens.length,
    }

    if (!fcm) {
      messageRecord.status = 'stored_only'
      messageRecord.error =
        initError ||
        'No serviceAccount.json — notification saved but not pushed via FCM'
      data.messages.push(messageRecord)
      write(data)
      return messageRecord
    }

    try {
      if (topic) {
        const result = await fcm.send({
          topic: String(topic),
          notification: { title: cleanTitle, body: cleanBody },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              channelId: 'chkela_default',
            },
          },
        })
        messageRecord.status = 'sent'
        messageRecord.successCount = 1
        messageRecord.fcmMessageId = result
      } else {
        if (tokens.length === 0) {
          messageRecord.status = 'failed'
          messageRecord.error = targetPhone
            ? 'No device tokens for that phone'
            : 'No registered device tokens. Users must open the app while signed in.'
          data.messages.push(messageRecord)
          write(data)
          return messageRecord
        }

        let successCount = 0
        let failureCount = 0
        const errors = []
        // FCM multicast limit is 500 tokens per request.
        for (let i = 0; i < tokens.length; i += 500) {
          const chunk = tokens.slice(i, i + 500)
          const result = await fcm.sendEachForMulticast({
            tokens: chunk,
            notification: { title: cleanTitle, body: cleanBody },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                channelId: 'chkela_default',
              },
            },
          })
          successCount += result.successCount
          failureCount += result.failureCount
          result.responses?.forEach((response, index) => {
            if (!response.success) {
              errors.push(
                `${chunk[index]?.slice(0, 12) || '?'}…: ${
                  response.error?.message || 'failed'
                }`,
              )
            }
          })
        }

        messageRecord.status =
          successCount > 0 ? 'sent' : failureCount > 0 ? 'failed' : 'sent'
        messageRecord.successCount = successCount
        messageRecord.failureCount = failureCount
        if (errors.length > 0) {
          messageRecord.error = errors.slice(0, 5).join(' | ')
        }
      }
    } catch (error) {
      messageRecord.status = 'failed'
      messageRecord.error =
        error instanceof Error ? error.message : 'FCM send failed'
    }

    data.messages.push(messageRecord)
    write(data)
    return messageRecord
  }

  function status() {
    const accountFile =
      serviceAccountPath ||
      resolve(dirname(filePath), 'serviceAccount.json')
    const fcm = getMessaging()
    return {
      fcmReady: Boolean(fcm),
      tokenCount: read().tokens.length,
      serviceAccountPath: accountFile,
      initError: initError || null,
    }
  }

  return { listTokens, listMessages, register, send, status }
}

function ensureFile(filePath) {
  const dir = dirname(filePath)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  if (!existsSync(filePath)) {
    writeFileSync(filePath, `${JSON.stringify(EMPTY, null, 2)}\n`, 'utf8')
  }
}

function normalizePhone(value) {
  if (value == null || value === '') return null
  const digits = String(value).replace(/[^\d+]/g, '').trim()
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

