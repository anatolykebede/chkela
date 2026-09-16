import { pool } from '../db.mjs'
import { httpError } from './tokens.mjs'

const LIMITS = {
  tutor: Number(process.env.AI_FREE_TUTOR_LIMIT || 3),
  wrong_answer: Number(process.env.AI_FREE_WRONG_LIMIT || 20),
  explain: Number(process.env.AI_FREE_EXPLAIN_LIMIT || 20),
  translate: Number(process.env.AI_FREE_TRANSLATE_LIMIT || 40),
}

export function freeLimitFor(feature) {
  return LIMITS[feature] ?? 3
}

export async function consumeAiQuota(phone, feature) {
  const limit = freeLimitFor(feature)
  const day = new Date().toISOString().slice(0, 10)
  const result = await pool.query(
    `INSERT INTO ai_usage (phone, day, feature, count)
     VALUES ($1, $2::date, $3, 1)
     ON CONFLICT (phone, day, feature)
     DO UPDATE SET count = ai_usage.count + 1
     WHERE ai_usage.count < $4
     RETURNING count`,
    [phone, day, feature, limit],
  )
  if (!result.rowCount) {
      throw httpError(
        'Free AI limit reached. Subscribe to keep using Chkela AI, or try again tomorrow.',
        429,
      )
  }
  return {
    used: result.rows[0].count,
    limit,
    remaining: Math.max(0, limit - result.rows[0].count),
  }
}

export async function peekAiQuota(phone, feature) {
  const limit = freeLimitFor(feature)
  const day = new Date().toISOString().slice(0, 10)
  const result = await pool.query(
    `SELECT count FROM ai_usage
     WHERE phone = $1 AND day = $2::date AND feature = $3`,
    [phone, day, feature],
  )
  const used = result.rows[0]?.count ?? 0
  return { used, limit, remaining: Math.max(0, limit - used) }
}
