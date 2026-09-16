import DOMPurify from 'isomorphic-dompurify'

/** Client-side CMS HTML sanitizer (preview + save). */
export function sanitizeCmsHtml(dirty: string): string {
  return DOMPurify.sanitize(String(dirty ?? ''), {
    USE_PROFILES: { html: true },
    ADD_ATTR: ['class', 'target', 'rel', 'id'],
    FORBID_TAGS: ['script', 'iframe', 'object', 'embed', 'form'],
    FORBID_ATTR: ['srcdoc'],
  })
}
