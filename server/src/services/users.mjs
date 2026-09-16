import { pool } from '../db.mjs'
import { normalizePhone } from './friends.mjs'

function rowToUser(row, plan = 'free') {
  if (!row) return null
  return {
    id: row.phone,
    phone: row.phone,
    name: row.display_name || row.phone,
    displayName: row.display_name || '',
    grade: row.grade || '',
    birthdate: row.birthdate || null,
    interests: Array.isArray(row.interests) ? row.interests : [],
    plan: plan || 'free',
    status: row.status || 'active',
    onboardingComplete: Boolean(row.onboarding_complete),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    joined: row.created_at
      ? new Date(row.created_at).toISOString().slice(0, 10)
      : '',
  }
}

export async function registerUserFromOtp(phoneRaw) {
  const phone = normalizePhone(phoneRaw)
  if (!phone) throw new Error('phone_required')

  const r = await pool.query(
    `INSERT INTO app_users (phone, status, created_at, updated_at)
     VALUES ($1, 'active', NOW(), NOW())
     ON CONFLICT (phone) DO UPDATE SET
       status = 'active',
       updated_at = NOW()
     RETURNING *`,
    [phone],
  )
  return rowToUser(r.rows[0])
}

export async function getUserByPhone(phoneRaw) {
  const phone = normalizePhone(phoneRaw)
  if (!phone) return null
  const r = await pool.query('SELECT * FROM app_users WHERE phone=$1 LIMIT 1', [
    phone,
  ])
  if (!r.rows[0]) return null
  return rowToUser(r.rows[0])
}

export async function updateUserProfile({
  phone: phoneRaw,
  displayName,
  grade,
  birthdate,
  interests,
  onboardingComplete,
}) {
  const phone = normalizePhone(phoneRaw)
  if (!phone) throw new Error('phone_required')

  // Ensure row exists (OTP may have been verified before this table existed).
  await registerUserFromOtp(phone)

  const fields = []
  const values = []
  let i = 1

  if (displayName !== undefined) {
    fields.push(`display_name = $${i++}`)
    values.push(String(displayName || '').trim())
  }
  if (grade !== undefined) {
    fields.push(`grade = $${i++}`)
    values.push(String(grade || '').trim())
  }
  if (birthdate !== undefined) {
    fields.push(`birthdate = $${i++}`)
    values.push(birthdate ? String(birthdate) : null)
  }
  if (interests !== undefined) {
    fields.push(`interests = $${i++}::jsonb`)
    values.push(JSON.stringify(Array.isArray(interests) ? interests : []))
  }
  if (onboardingComplete !== undefined) {
    fields.push(`onboarding_complete = $${i++}`)
    values.push(Boolean(onboardingComplete))
  }

  if (fields.length === 0) {
    const existing = await pool.query('SELECT * FROM app_users WHERE phone=$1', [
      phone,
    ])
    return rowToUser(existing.rows[0])
  }

  fields.push('updated_at = NOW()')
  values.push(phone)

  const r = await pool.query(
    `UPDATE app_users SET ${fields.join(', ')} WHERE phone = $${i} RETURNING *`,
    values,
  )
  return rowToUser(r.rows[0])
}

export async function listUsers() {
  const r = await pool.query(
    `SELECT u.*,
            COALESCE(s.plan, 'free') AS plan_name,
            COALESCE(s.status, '') AS sub_status
     FROM app_users u
     LEFT JOIN subscriptions s ON s.phone = u.phone
     ORDER BY u.created_at DESC`,
  )

  return r.rows.map((row) => {
    const paid =
      row.sub_status === 'active' && row.plan_name && row.plan_name !== 'free'
    return rowToUser(row, paid ? row.plan_name : 'free')
  })
}

function rowToDeletedUser(row) {
  if (!row) return null
  return {
    id: String(row.id),
    phone: row.phone,
    name: row.display_name || row.phone,
    displayName: row.display_name || '',
    grade: row.grade || '',
    birthdate: row.birthdate || null,
    interests: Array.isArray(row.interests) ? row.interests : [],
    plan: row.plan || 'free',
    status: 'deleted',
    onboardingComplete: Boolean(row.onboarding_complete),
    registeredAt: row.registered_at,
    deletedAt: row.deleted_at,
    joined: row.registered_at
      ? new Date(row.registered_at).toISOString().slice(0, 10)
      : '',
    deleted: row.deleted_at
      ? new Date(row.deleted_at).toISOString().slice(0, 10)
      : '',
  }
}

export async function listDeletedUsers() {
  const r = await pool.query(
    `SELECT * FROM deleted_users ORDER BY deleted_at DESC`,
  )
  return r.rows.map(rowToDeletedUser)
}

/**
 * Archive the account, wipe related server rows, and remove from app_users
 * so the next OTP verify creates a brand-new user.
 */
export async function deleteUserAccount(phoneRaw) {
  const phone = normalizePhone(phoneRaw)
  if (!phone) throw new Error('phone_required')

  const client = await pool.connect()
  try {
    await client.query('BEGIN')

    const existing = await client.query(
      'SELECT * FROM app_users WHERE phone=$1 LIMIT 1',
      [phone],
    )
    if (!existing.rows[0]) {
      await client.query('DELETE FROM leaderboard_scores WHERE phone=$1', [phone])
      await client.query('COMMIT')
      return { ok: true, alreadyDeleted: true }
    }

    const user = existing.rows[0]
    const sub = await client.query(
      `SELECT plan, status FROM subscriptions WHERE phone=$1 LIMIT 1`,
      [phone],
    )
    const subRow = sub.rows[0]
    const plan =
      subRow && subRow.status === 'active' && subRow.plan && subRow.plan !== 'free'
        ? subRow.plan
        : 'free'

    await client.query(
      `INSERT INTO deleted_users (
         phone, display_name, grade, birthdate, interests, plan,
         onboarding_complete, registered_at, deleted_at
       ) VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, $8, NOW())`,
      [
        phone,
        user.display_name || '',
        user.grade || '',
        user.birthdate || null,
        JSON.stringify(
          Array.isArray(user.interests) ? user.interests : [],
        ),
        plan,
        Boolean(user.onboarding_complete),
        user.created_at || null,
      ],
    )

    const profile = await client.query(
      'SELECT map_id FROM profiles WHERE phone=$1 LIMIT 1',
      [phone],
    )
    const mapId = profile.rows[0]?.map_id || null

    await client.query('DELETE FROM device_tokens WHERE phone=$1', [phone])
    await client.query('DELETE FROM subscriptions WHERE phone=$1', [phone])
    await client.query(
      `DELETE FROM friendships
       WHERE from_phone=$1
          OR to_id=$1
          OR ($2::text IS NOT NULL AND to_id=$2)`,
      [phone, mapId],
    )
    await client.query(
      `DELETE FROM profile_views
       WHERE viewer_phone=$1 OR target_phone=$1`,
      [phone],
    )

    const convs = await client.query(
      `SELECT id FROM conversations
       WHERE participant_a=$1 OR participant_b=$1
          OR ($2::text IS NOT NULL AND (participant_a=$2 OR participant_b=$2))`,
      [phone, mapId],
    )
    for (const row of convs.rows) {
      await client.query('DELETE FROM conversations WHERE id=$1', [row.id])
    }

    await client.query('DELETE FROM profiles WHERE phone=$1', [phone])
    await client.query('DELETE FROM leaderboard_scores WHERE phone=$1', [phone])
    await client.query('DELETE FROM app_users WHERE phone=$1', [phone])

    await client.query('COMMIT')
    return { ok: true, alreadyDeleted: false }
  } catch (error) {
    try {
      await client.query('ROLLBACK')
    } catch (_) {
      /* ignore */
    }
    throw error
  } finally {
    client.release()
  }
}
