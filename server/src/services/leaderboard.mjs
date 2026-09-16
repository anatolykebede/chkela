import { pool } from '../db.mjs'
import { normalizePhone } from './friends.mjs'

function rowToEntry(row) {
  return {
    phone: row.phone,
    name: row.display_name || 'Student',
    displayName: row.display_name || '',
    grade: row.grade || '',
    points: Number(row.points) || 0,
    updatedAt: row.updated_at,
  }
}

export async function upsertLeaderboardScore({
  phone: phoneRaw,
  displayName,
  grade,
  points,
}) {
  const phone = normalizePhone(phoneRaw)
  if (!phone) throw new Error('phone_required')

  const name = String(displayName || '').trim()
  const gradeLabel = String(grade || '').trim()
  const score = Math.max(0, Math.floor(Number(points) || 0))

  const r = await pool.query(
    `INSERT INTO leaderboard_scores (phone, display_name, grade, points, updated_at)
     VALUES ($1, $2, $3, $4, NOW())
     ON CONFLICT (phone) DO UPDATE SET
       display_name = EXCLUDED.display_name,
       grade = EXCLUDED.grade,
       points = EXCLUDED.points,
       updated_at = NOW()
     RETURNING *`,
    [phone, name, gradeLabel, score],
  )
  return rowToEntry(r.rows[0])
}

export async function listLeaderboardByGrade(gradeRaw, { limit = 100 } = {}) {
  const grade = String(gradeRaw || '').trim()
  if (!grade) return []

  const capped = Math.min(Math.max(Number(limit) || 100, 1), 200)
  const r = await pool.query(
    `SELECT * FROM leaderboard_scores
     WHERE grade = $1
     ORDER BY points DESC, updated_at ASC
     LIMIT $2`,
    [grade, capped],
  )
  return r.rows.map(rowToEntry)
}

export async function deleteLeaderboardScore(phoneRaw) {
  const phone = normalizePhone(phoneRaw)
  if (!phone) return
  await pool.query('DELETE FROM leaderboard_scores WHERE phone=$1', [phone])
}
