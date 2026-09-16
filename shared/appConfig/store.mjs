import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'

export const DEFAULT_APP_CONFIG = {
  contact: {
    supportEmail: 'contact@chkela.com',
    supportPhoneDisplay: '+251 947 819 388',
    supportPhoneTel: '+251947819388',
    website: 'https://www.chkela.com',
    telegramUsername: 'chkelaadmin',
  },
  social: {
    instagramUrl: 'https://www.instagram.com/chkela.app',
    tiktokUrl: 'https://www.tiktok.com/@chkela.app',
    youtubeUrl: 'https://www.youtube.com/@chkela',
    facebookUrl: 'https://www.facebook.com/chkela.app',
    xUrl: 'https://x.com/chkela_app',
  },
  updatedAt: null,
}

export function createAppConfigStore(filePath) {
  ensureFile(filePath)

  function read() {
    try {
      const raw = readFileSync(filePath, 'utf8')
      const parsed = JSON.parse(raw)
      return normalizeConfig(parsed)
    } catch {
      return structuredClone(DEFAULT_APP_CONFIG)
    }
  }

  function write(data) {
    writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8')
  }

  function get() {
    return read()
  }

  function update(patch) {
    const current = read()
    const next = normalizeConfig({
      contact: { ...current.contact, ...(patch.contact || {}) },
      social: { ...current.social, ...(patch.social || {}) },
      updatedAt: new Date().toISOString(),
    })
    write(next)
    return next
  }

  return { get, update }
}

function normalizeConfig(raw) {
  const contact = raw?.contact || {}
  const social = raw?.social || {}
  const telegramUsername = String(
    contact.telegramUsername || DEFAULT_APP_CONFIG.contact.telegramUsername,
  )
    .trim()
    .replace(/^@/, '')

  return {
    contact: {
      supportEmail: String(
        contact.supportEmail || DEFAULT_APP_CONFIG.contact.supportEmail,
      ).trim(),
      supportPhoneDisplay: String(
        contact.supportPhoneDisplay ||
          DEFAULT_APP_CONFIG.contact.supportPhoneDisplay,
      ).trim(),
      supportPhoneTel: String(
        contact.supportPhoneTel || DEFAULT_APP_CONFIG.contact.supportPhoneTel,
      )
        .replace(/[^\d+]/g, '')
        .trim(),
      website: String(contact.website || DEFAULT_APP_CONFIG.contact.website).trim(),
      telegramUsername,
    },
    social: {
      instagramUrl: String(
        social.instagramUrl || DEFAULT_APP_CONFIG.social.instagramUrl,
      ).trim(),
      tiktokUrl: String(
        social.tiktokUrl || DEFAULT_APP_CONFIG.social.tiktokUrl,
      ).trim(),
      youtubeUrl: String(
        social.youtubeUrl || DEFAULT_APP_CONFIG.social.youtubeUrl,
      ).trim(),
      facebookUrl: String(
        social.facebookUrl || DEFAULT_APP_CONFIG.social.facebookUrl,
      ).trim(),
      xUrl: String(social.xUrl || DEFAULT_APP_CONFIG.social.xUrl).trim(),
    },
    updatedAt: raw?.updatedAt || null,
  }
}

function ensureFile(filePath) {
  const dir = dirname(filePath)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  if (!existsSync(filePath)) {
    writeFileSync(
      filePath,
      `${JSON.stringify(DEFAULT_APP_CONFIG, null, 2)}\n`,
      'utf8',
    )
  }
}
