import { createRequire } from 'node:module'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const require = createRequire(
  path.join(path.dirname(fileURLToPath(import.meta.url)), '../dashboard/package.json'),
)
const DOMPurify = require('isomorphic-dompurify')

const HTML_KEYS = new Set([
  'bodyHtml',
  'html',
  'content',
  'body',
  'overview',
  'summary',
  'text',
  'description',
])

/** Strip XSS vectors from CMS HTML while keeping useful markup. */
export function sanitizeCmsHtml(dirty) {
  return DOMPurify.sanitize(String(dirty ?? ''), {
    USE_PROFILES: { html: true },
    ADD_ATTR: ['class', 'target', 'rel', 'id'],
    FORBID_TAGS: ['script', 'iframe', 'object', 'embed', 'form'],
    FORBID_ATTR: ['srcdoc'],
  })
}

/** Deep-sanitize known HTML string fields on CMS payloads. */
export function sanitizeCmsPayload(value) {
  if (typeof value === 'string') return value
  if (Array.isArray(value)) {
    return value.map((item) => sanitizeCmsPayload(item))
  }
  if (!value || typeof value !== 'object') return value
  const out = {}
  for (const [key, raw] of Object.entries(value)) {
    if (typeof raw === 'string' && HTML_KEYS.has(key)) {
      out[key] = sanitizeCmsHtml(raw)
    } else if (raw && typeof raw === 'object') {
      out[key] = sanitizeCmsPayload(raw)
    } else {
      out[key] = raw
    }
  }
  return out
}

/** Remove scriptable bits from uploaded SVG. */
export function scrubSvgBuffer(buffer) {
  let text = buffer.toString('utf8')
  text = text.replace(/<script[\s\S]*?<\/script>/gi, '')
  text = text.replace(/\son\w+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi, '')
  text = text.replace(/javascript:/gi, '')
  text = text.replace(/<foreignObject[\s\S]*?<\/foreignObject>/gi, '')
  return Buffer.from(text, 'utf8')
}
