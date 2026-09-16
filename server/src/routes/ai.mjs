import {
  phoneFromSession,
  requireUser,
} from '../services/auth_guards.mjs'
import { generateGeminiText, geminiConfigured } from '../services/gemini.mjs'
import { consumeAiQuota, peekAiQuota } from '../services/ai_usage.mjs'
import { httpError } from '../services/tokens.mjs'

function clip(value, max = 4000) {
  const text = String(value || '').trim()
  if (text.length <= max) return text
  return `${text.slice(0, max)}…`
}

function contextBlock(ctx = {}) {
  const grade = clip(ctx.grade, 40)
  const subject = clip(ctx.subject, 80)
  const chapter = clip(ctx.chapter, 120)
  const note = clip(ctx.note, 120)
  const snippet = clip(ctx.noteSnippet || ctx.snippet, 2500)
  const lines = [
    grade && `Grade: ${grade}`,
    subject && `Subject: ${subject}`,
    chapter && `Chapter: ${chapter}`,
    note && `Note / lesson: ${note}`,
    snippet && `Relevant note excerpt:\n${snippet}`,
  ].filter(Boolean)
  return lines.length ? lines.join('\n') : 'No specific study context.'
}

export default async function aiRoutes(app) {
  app.get(
    '/api/ai/quota',
    { config: { rateLimit: { max: 30, timeWindow: '1 minute' } } },
    async (req) => {
      await requireUser(req)
      const phone = phoneFromSession(req)
      const feature = String(req.query?.feature || 'tutor')
      return { ok: true, ...(await peekAiQuota(phone, feature)) }
    },
  )

  app.post(
    '/api/ai/tutor',
    { config: { rateLimit: { max: 20, timeWindow: '1 minute' } } },
    async (req) => {
      await requireUser(req)
      if (!geminiConfigured()) throw httpError('AI is not configured', 503)
      const phone = phoneFromSession(req)
      const body = req.body || {}
      const message = clip(body.message, 1500)
      if (!message) throw httpError('message is required')

      const weakSpots = Array.isArray(body.weakSpots)
        ? body.weakSpots.slice(0, 8).map((item) => clip(item, 200))
        : []

      const quota = await consumeAiQuota(phone, 'tutor')
      const ctx = body.context || {}

      const system = `You are Chkela's study coach for Ethiopian secondary students (Grades 9–12).
Be clear, encouraging, and exam-ready. Prefer short paragraphs and bullet steps.
Use the provided grade/subject/chapter/note context. If the student asks to quiz them, ask 3–5 short questions (one at a time or as a short list with answers after).
If they ask about weak spots, use the weakSpots list when present.
Do not invent MoE syllabus claims you are unsure about. Keep math readable in plain text.`

      const user = `Study context:
${contextBlock(ctx)}

Recent weak spots (wrong answers / missed skills):
${weakSpots.length ? weakSpots.map((w) => `- ${w}`).join('\n') : '- none recorded yet'}

Student message:
${message}`

      const reply = await generateGeminiText({
        system,
        user,
        maxOutputTokens: 900,
      })

      return { ok: true, reply, quota }
    },
  )

  app.post(
    '/api/ai/wrong-answer',
    { config: { rateLimit: { max: 30, timeWindow: '1 minute' } } },
    async (req) => {
      await requireUser(req)
      if (!geminiConfigured()) throw httpError('AI is not configured', 503)
      const phone = phoneFromSession(req)
      const body = req.body || {}
      const question = clip(body.question, 1200)
      if (!question) throw httpError('question is required')

      const quota = await consumeAiQuota(phone, 'wrong_answer')
      const options = Array.isArray(body.options)
        ? body.options.slice(0, 6).map((o) => clip(o, 300))
        : []
      const studentAnswer = clip(body.studentAnswer, 400)
      const correctAnswer = clip(body.correctAnswer, 400)
      const explanation = clip(body.explanation, 1200)

      const system = `You are Chkela's wrong-answer coach.
Reply in this exact structure with short lines:
Why: <1–2 sentences>
Rule: <the key rule or concept>
Practice: <one similar practice question only, no answer>`

      const user = `Context:
${contextBlock(body.context || {})}

Question: ${question}
Options: ${options.length ? options.join(' | ') : 'n/a'}
Student chose: ${studentAnswer || 'n/a'}
Correct answer: ${correctAnswer || 'n/a'}
Existing explanation: ${explanation || 'n/a'}`

      const reply = await generateGeminiText({
        system,
        user,
        maxOutputTokens: 450,
      })

      return { ok: true, reply, quota }
    },
  )

  app.post(
    '/api/ai/explain',
    { config: { rateLimit: { max: 30, timeWindow: '1 minute' } } },
    async (req) => {
      await requireUser(req)
      if (!geminiConfigured()) throw httpError('AI is not configured', 503)
      const phone = phoneFromSession(req)
      const body = req.body || {}
      const selection = clip(body.selection || body.text, 2500)
      if (!selection) throw httpError('selection is required')

      const quota = await consumeAiQuota(phone, 'explain')

      const system = `You are Chkela's note explainer for secondary students.
Explain in clear plain English only. Do not add Amharic or any other language.
Focus only on the selected text. Be concise. Use bullets for steps/formulas.`

      const user = `Context:
${contextBlock(body.context || {})}

Selected note text:
${selection}`

      const reply = await generateGeminiText({
        system,
        user,
        maxOutputTokens: 700,
      })

      return { ok: true, reply, quota }
    },
  )

  app.post(
    '/api/ai/translate',
    { config: { rateLimit: { max: 30, timeWindow: '1 minute' } } },
    async (req) => {
      await requireUser(req)
      if (!geminiConfigured()) throw httpError('AI is not configured', 503)
      const phone = phoneFromSession(req)
      const body = req.body || {}
      const text = clip(body.text || body.source || '', 4000)
      if (!text) throw httpError('text is required')

      const target = normalizeTranslateTarget(body.target || body.language)
      if (!target) {
        throw httpError(
          'target must be one of: amharic, oromo, tigrigna, somali, afar',
        )
      }

      const quota = await consumeAiQuota(phone, 'translate')

      const system = `You are a careful translator for Ethiopian secondary students.
Translate the user's English study explanation into ${target.label} only.
Keep scientific terms clear. Preserve meaning, bullets, and structure.
Do not add English commentary. Output only the translation.`

      const reply = await generateGeminiText({
        system,
        user: text,
        maxOutputTokens: 900,
      })

      return {
        ok: true,
        reply,
        target: target.code,
        targetLabel: target.label,
        quota,
      }
    },
  )
}

const TRANSLATE_TARGETS = {
  am: { code: 'am', label: 'Amharic (አማርኛ)' },
  amharic: { code: 'am', label: 'Amharic (አማርኛ)' },
  om: { code: 'om', label: 'Afaan Oromo' },
  oromo: { code: 'om', label: 'Afaan Oromo' },
  afaan_oromo: { code: 'om', label: 'Afaan Oromo' },
  ti: { code: 'ti', label: 'Tigrigna (ትግርኛ)' },
  tigrigna: { code: 'ti', label: 'Tigrigna (ትግርኛ)' },
  tigrinya: { code: 'ti', label: 'Tigrigna (ትግርኛ)' },
  so: { code: 'so', label: 'Somali' },
  somali: { code: 'so', label: 'Somali' },
  aa: { code: 'aa', label: 'Afar' },
  afar: { code: 'aa', label: 'Afar' },
}

function normalizeTranslateTarget(raw) {
  const key = String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, '_')
  return TRANSLATE_TARGETS[key] || null
}
