import { useRef, useState } from 'react'
import katex from 'katex'
import { sanitizeCmsHtml } from '../lib/sanitizeHtml'
import 'katex/dist/katex.min.css'
import { ImagePlus, Loader2 } from 'lucide-react'
import { uploadMedia } from '../lib/contentApi'

type RichContentFieldsProps = {
  label: string
  value: string
  onChange: (next: string) => void
  rows?: number
  placeholder?: string
  /** When true, insert images as HTML <img>. Otherwise append markdown-ish path hint. */
  htmlMode?: boolean
  required?: boolean
}

/** Textarea with media upload + KaTeX live preview ($...$ / $$...$$). */
export function RichContentFields({
  label,
  value,
  onChange,
  rows = 8,
  placeholder,
  htmlMode = true,
  required,
}: RichContentFieldsProps) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState('')

  async function onPickFile(file: File | null) {
    if (!file) return
    setUploading(true)
    setError('')
    try {
      const uploaded = await uploadMedia(file)
      const snippet = htmlMode
        ? `\n<p><img src="${uploaded.url}" alt="" style="max-width:100%;height:auto;" /></p>\n`
        : `\n![${file.name}](${uploaded.url})\n`
      onChange(`${value.trimEnd()}${snippet}`)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Upload failed')
    } finally {
      setUploading(false)
      if (inputRef.current) inputRef.current.value = ''
    }
  }

  return (
    <div className="rich-content-fields">
      <div className="rich-content-fields__head">
        <span>{label}</span>
        <button
          type="button"
          className="btn-ghost"
          disabled={uploading}
          onClick={() => inputRef.current?.click()}
        >
          {uploading ? <Loader2 size={14} className="spin" /> : <ImagePlus size={14} />}
          {uploading ? 'Uploading…' : 'Upload media'}
        </button>
        <input
          ref={inputRef}
          type="file"
          accept="image/*,video/mp4,video/webm,application/pdf"
          hidden
          onChange={(e) => void onPickFile(e.target.files?.[0] ?? null)}
        />
      </div>
      <textarea
        rows={rows}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        required={required}
      />
      <p className="rich-content-fields__hint">
        Equations: use <code>$E=mc^2$</code> inline or <code>{'$$\\frac{a}{b}$$'}</code>{' '}
        for display. Works for Maths, Physics, Chemistry, etc.
      </p>
      {error ? <p className="content-banner content-banner--error">{error}</p> : null}
      <KatexPreview source={value} htmlMode={htmlMode} />
    </div>
  )
}

function KatexPreview({
  source,
  htmlMode,
}: {
  source: string
  htmlMode: boolean
}) {
  const html = renderPreviewHtml(source, htmlMode)
  if (!source.trim()) return null
  return (
    <div className="katex-preview">
      <p className="katex-preview__label">Preview</p>
      <div
        className="katex-preview__body"
        dangerouslySetInnerHTML={{ __html: html }}
      />
    </div>
  )
}

function escapeHtml(text: string) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
}

function escapeAttr(text: string) {
  return escapeHtml(text).replace(/"/g, '&quot;')
}

/** Resolve markdown/upload figure paths for dashboard preview. */
function previewImageSrc(url: string) {
  const trimmed = url.trim()
  if (
    trimmed.startsWith('http://') ||
    trimmed.startsWith('https://') ||
    trimmed.startsWith('/')
  ) {
    return trimmed
  }
  if (trimmed.startsWith('figures/')) return `/${trimmed}`
  return trimmed
}

/** Turn `![alt](url)` into <img> before escaping the rest of the line. */
function replaceMarkdownImages(text: string) {
  return text.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (_match, alt, url) => {
    const src = previewImageSrc(String(url))
    return `<img src="${escapeAttr(src)}" alt="${escapeAttr(String(alt))}" />`
  })
}

/** Render $...$ / $$...$$ (and keep HTML if htmlMode). */
export function renderPreviewHtml(source: string, htmlMode: boolean) {
  const withMath = source.replace(/\$\$([\s\S]+?)\$\$|\$([^$\n]+?)\$/g, (match, display, inline) => {
    const tex = (display ?? inline ?? '').trim()
    if (!tex) return match
    try {
      return katex.renderToString(tex, {
        throwOnError: false,
        displayMode: Boolean(display),
      })
    } catch {
      return match
    }
  })
  if (htmlMode) return sanitizeCmsHtml(withMath)
  return withMath
    .split(/\n+/)
    .map((line) => {
      const withImages = replaceMarkdownImages(line)
      // Escape text around already-built <img> tags.
      const parts = withImages.split(/(<img\b[^>]*>)/g)
      const html = parts
        .map((part) => (part.startsWith('<img') ? part : escapeHtml(part)))
        .join('')
      return `<p>${html}</p>`
    })
    .join('')
}
