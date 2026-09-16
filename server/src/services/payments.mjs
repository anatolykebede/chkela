import { randomUUID } from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { pool } from '../db.mjs'
import { normalizePhone } from './friends.mjs'
import { upsertSubscription } from './subscriptions.mjs'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const uploadsDir = path.resolve(__dirname, '../../uploads/payments')

function ensureUploadsDir() {
  if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true })
  }
}

function rowToJson(row) {
  return {
    id: row.id,
    phone: row.phone,
    displayName: row.display_name || '',
    method: row.method,
    amount: Number(row.amount || 0),
    currency: row.currency || 'ETB',
    plan: row.plan,
    grades: Array.isArray(row.grades) ? row.grades : [],
    billingPeriod: row.billing_period,
    reference: row.reference || '',
    status: row.status,
    receiptPath: row.receipt_path || null,
    hasReceipt: Boolean(row.receipt_path),
    reviewedAt: row.reviewed_at?.toISOString?.() || null,
    createdAt: row.created_at?.toISOString?.() || null,
    updatedAt: row.updated_at?.toISOString?.() || null,
  }
}

function monthsForBillingPeriod(period) {
  const key = String(period || 'monthly').toLowerCase()
  if (key === 'sixmonth' || key === 'six_month' || key === '6month') return 6
  if (key === 'yearly' || key === 'year') return 12
  return 1
}

function expiresAtForPeriod(billingPeriod) {
  const months = monthsForBillingPeriod(billingPeriod)
  const d = new Date()
  d.setMonth(d.getMonth() + months)
  return d.toISOString()
}

export async function listPayments({ status } = {}) {
  const params = []
  let sql = 'SELECT * FROM payments'
  if (status) {
    params.push(String(status))
    sql += ` WHERE status = $${params.length}`
  }
  sql += ' ORDER BY created_at DESC'
  const r = await pool.query(sql, params)
  return r.rows.map(rowToJson)
}

export async function getPayment(id) {
  const r = await pool.query('SELECT * FROM payments WHERE id = $1 LIMIT 1', [id])
  return r.rows[0] ? rowToJson(r.rows[0]) : null
}

export function paymentReceiptAbsolutePath(relativePath) {
  if (!relativePath) return null
  const safe = path.basename(String(relativePath))
  return path.join(uploadsDir, safe)
}

export async function createPayment({
  phone,
  displayName = '',
  method = 'CBE',
  amount,
  plan = 'plus',
  grades = [],
  billingPeriod = 'monthly',
  reference = '',
  receiptBase64 = null,
  receiptMime = 'image/jpeg',
}) {
  const normalized = normalizePhone(phone)
  if (!normalized) throw new Error('phone_required')
  const amt = Number(amount)
  if (!Number.isFinite(amt) || amt <= 0) throw new Error('amount_required')

  const methodLabel =
    String(method || 'CBE').toUpperCase() === 'CHAPA' ? 'Chapa' : 'CBE'
  const id = `pay_${randomUUID().slice(0, 12)}`
  let receiptPath = null

  if (receiptBase64) {
    ensureUploadsDir()
    const raw = String(receiptBase64).replace(/^data:[^;]+;base64,/, '')
    const buf = Buffer.from(raw, 'base64')
    if (!buf.length) throw new Error('receipt_invalid')
    if (buf.length > 4 * 1024 * 1024) throw new Error('receipt_too_large')
    const ext = String(receiptMime || '').includes('png') ? 'png' : 'jpg'
    const fileName = `${id}.${ext}`
    fs.writeFileSync(path.join(uploadsDir, fileName), buf)
    receiptPath = fileName
  }

  const gradesJson = Array.isArray(grades)
    ? grades.map((g) => String(g))
    : []

  const r = await pool.query(
    `INSERT INTO payments (
       id, phone, display_name, method, amount, currency, plan, grades,
       billing_period, reference, status, receipt_path, created_at, updated_at
     ) VALUES (
       $1,$2,$3,$4,$5,'ETB',$6,$7::jsonb,$8,$9,'pending',$10,NOW(),NOW()
     ) RETURNING *`,
    [
      id,
      normalized,
      String(displayName || '').trim(),
      methodLabel,
      Math.round(amt),
      String(plan || 'plus'),
      JSON.stringify(gradesJson),
      String(billingPeriod || 'monthly'),
      String(reference || '').trim(),
      receiptPath,
    ],
  )
  return rowToJson(r.rows[0])
}

export async function approvePayment(id) {
  const existing = await pool.query('SELECT * FROM payments WHERE id = $1 LIMIT 1', [
    id,
  ])
  const row = existing.rows[0]
  if (!row) throw Object.assign(new Error('payment_not_found'), { statusCode: 404 })
  if (row.status === 'verified') {
    return { payment: rowToJson(row), subscription: null, already: true }
  }
  if (row.status === 'rejected') {
    throw Object.assign(new Error('payment_already_rejected'), { statusCode: 400 })
  }

  const expiresAt = expiresAtForPeriod(row.billing_period)
  let grades = Array.isArray(row.grades) ? row.grades : []
  try {
    if (typeof row.grades === 'string') grades = JSON.parse(row.grades)
  } catch {
    grades = []
  }
  const subscription = await upsertSubscription({
    phone: row.phone,
    plan: row.plan || 'plus',
    status: 'active',
    expiresAt,
    grades,
    mergeGradesWithExisting: true,
  })

  const updated = await pool.query(
    `UPDATE payments
     SET status = 'verified', reviewed_at = NOW(), updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [id],
  )
  return { payment: rowToJson(updated.rows[0]), subscription, already: false }
}

export async function rejectPayment(id, reason = '') {
  const existing = await pool.query('SELECT * FROM payments WHERE id = $1 LIMIT 1', [
    id,
  ])
  const row = existing.rows[0]
  if (!row) throw Object.assign(new Error('payment_not_found'), { statusCode: 404 })
  if (row.status === 'verified') {
    throw Object.assign(new Error('payment_already_verified'), { statusCode: 400 })
  }
  if (row.status === 'rejected') {
    return { payment: rowToJson(row), already: true }
  }

  const updated = await pool.query(
    `UPDATE payments
     SET status = 'rejected',
         reference = CASE
           WHEN $2::text = '' THEN reference
           ELSE COALESCE(NULLIF(reference, ''), $2::text)
         END,
         reviewed_at = NOW(),
         updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [id, String(reason || '').trim()],
  )
  return { payment: rowToJson(updated.rows[0]), already: false }
}

export async function latestPaymentForPhone(rawPhone) {
  const phone = normalizePhone(rawPhone)
  if (!phone) return null
  const r = await pool.query(
    `SELECT * FROM payments WHERE phone = $1 ORDER BY created_at DESC LIMIT 1`,
    [phone],
  )
  return r.rows[0] ? rowToJson(r.rows[0]) : null
}
