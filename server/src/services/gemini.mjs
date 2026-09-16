import { httpError } from './tokens.mjs'

const GEMINI_MODEL =
  String(process.env.GEMINI_MODEL || 'gemini-3.5-flash-lite').trim() ||
  'gemini-3.5-flash-lite'

export function geminiConfigured() {
  return Boolean(String(process.env.GEMINI_API_KEY || '').trim())
}

/**
 * Call Gemini generateContent. Returns plain text.
 * @param {{ system: string, user: string, maxOutputTokens?: number }} opts
 */
export async function generateGeminiText({
  system,
  user,
  maxOutputTokens = 700,
}) {
  const apiKey = String(process.env.GEMINI_API_KEY || '').trim()
  if (!apiKey) throw httpError('AI is not configured', 503)

  const url = new URL(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
  )
  url.searchParams.set('key', apiKey)

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: system }],
      },
      contents: [
        {
          role: 'user',
          parts: [{ text: user }],
        },
      ],
      generationConfig: {
        temperature: 0.4,
        maxOutputTokens,
      },
    }),
  })

  const data = await response.json().catch(() => ({}))
  if (!response.ok) {
    const message =
      data?.error?.message ||
      `Gemini request failed (${response.status})`
    const error = httpError(message, response.status === 429 ? 429 : 502)
    throw error
  }

  const text = extractText(data)
  if (!text) throw httpError('Empty AI response', 502)
  return text
}

function extractText(data) {
  const parts = data?.candidates?.[0]?.content?.parts
  if (!Array.isArray(parts)) return ''
  return parts
    .map((part) => (typeof part?.text === 'string' ? part.text : ''))
    .join('')
    .trim()
}
