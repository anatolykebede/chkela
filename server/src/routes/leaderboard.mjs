import {
  listLeaderboardByGrade,
  upsertLeaderboardScore,
} from '../services/leaderboard.mjs'
import { httpError } from '../services/tokens.mjs'
import {
  phoneFromSession,
  requireUser,
} from '../services/auth_guards.mjs'

export default async function leaderboardRoutes(app) {
  app.get('/api/leaderboard', async (req) => {
    const grade = String(req.query?.grade || '').trim()
    if (!grade) throw httpError('grade is required')
    const limit = Number(req.query?.limit || 100)
    const entries = await listLeaderboardByGrade(grade, { limit })
    return { entries, total: entries.length, grade }
  })

  app.post('/api/leaderboard/score', async (req) => {
    await requireUser(req)
    const body = req.body || {}
    const phone = phoneFromSession(req, body.phone)
    const grade = String(body.grade || '').trim()
    if (!grade) throw httpError('grade is required')

    const entry = await upsertLeaderboardScore({
      phone,
      displayName: body.displayName ?? body.name,
      grade,
      points: body.points,
    })
    return { ok: true, entry }
  })
}
