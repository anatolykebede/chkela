import fs from 'node:fs'
import {
  approvePayment,
  createPayment,
  getPayment,
  listPayments,
  paymentReceiptAbsolutePath,
  rejectPayment,
  latestPaymentForPhone,
} from '../services/payments.mjs'
import { findSubscriptionByPhone, isPaid } from '../services/subscriptions.mjs'
import { sendPush } from '../services/push.mjs'
import { httpError } from '../services/tokens.mjs'
import {
  phoneFromSession,
  requireAdmin,
  requireUser,
} from '../services/auth_guards.mjs'

export default async function paymentRoutes(app) {
  app.get('/api/payments', async (req) => {
    await requireAdmin(req)
    const status = req.query?.status ? String(req.query.status) : undefined
    return { payments: await listPayments({ status }) }
  })

  app.get('/api/payments/:id', async (req) => {
    await requireAdmin(req)
    const payment = await getPayment(req.params.id)
    if (!payment) throw httpError('Payment not found', 404)
    return { payment }
  })

  app.get('/api/payments/:id/receipt', async (req, reply) => {
    await requireAdmin(req)
    const payment = await getPayment(req.params.id)
    if (!payment?.receiptPath) throw httpError('Receipt not found', 404)
    const abs = paymentReceiptAbsolutePath(payment.receiptPath)
    if (!abs || !fs.existsSync(abs)) throw httpError('Receipt file missing', 404)
    const ext = abs.endsWith('.png') ? 'image/png' : 'image/jpeg'
    reply.type(ext)
    return reply.send(fs.createReadStream(abs))
  })

  app.post(
    '/api/payments',
    {
      bodyLimit: 5 * 1024 * 1024,
      config: {
        rateLimit: { max: 8, timeWindow: '1 minute' },
      },
    },
    async (req, reply) => {
      await requireUser(req)
      const body = req.body || {}
      const phone = phoneFromSession(req, body.phone)
      try {
        const payment = await createPayment({
          phone,
          displayName: body.displayName || req.user?.name || '',
          method: body.method,
          amount: body.amount,
          plan: body.plan,
          grades: body.grades,
          billingPeriod: body.billingPeriod,
          reference: body.reference,
          receiptBase64: body.receiptBase64,
          receiptMime: body.receiptMime,
        })
        reply.code(201)
        return { ok: true, payment }
      } catch (error) {
        const message = error instanceof Error ? error.message : 'submit_failed'
        if (message === 'phone_required') throw httpError('Phone required', 400)
        if (message === 'amount_required') throw httpError('Amount required', 400)
        if (message === 'receipt_too_large') {
          throw httpError('Receipt is too large (max 4MB)', 413)
        }
        if (message === 'receipt_invalid') throw httpError('Invalid receipt', 400)
        throw error
      }
    },
  )

  app.post('/api/payments/:id/approve', async (req) => {
    await requireAdmin(req)
    try {
      const result = await approvePayment(req.params.id)
      let push = null
      if (!result.already && result.payment?.phone) {
        try {
          push = await sendPush({
            title: 'Payment approved',
            body: 'Your Chkela plan is active. Open Study to unlock every subject.',
            phone: result.payment.phone,
            audience: 'phone',
            data: {
              type: 'payment_approved',
              paymentId: result.payment.id,
              plan: result.payment.plan || 'plus',
            },
          })
        } catch (error) {
          push = {
            ok: false,
            error:
              error instanceof Error ? error.message : 'push_failed',
          }
        }
      }
      return { ok: true, ...result, push }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'approve_failed'
      const code = error?.statusCode || 400
      throw httpError(message, code)
    }
  })

  app.post('/api/payments/:id/reject', async (req) => {
    await requireAdmin(req)
    try {
      const result = await rejectPayment(req.params.id, req.body?.reason)
      return { ok: true, ...result }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'reject_failed'
      const code = error?.statusCode || 400
      throw httpError(message, code)
    }
  })

  /** Signed-in student: paid status + latest payment. */
  app.get('/api/subscriptions/me', async (req) => {
    await requireUser(req)
    const phone = phoneFromSession(req)
    const paid = await isPaid(phone)
    const subscription = await findSubscriptionByPhone(phone)
    const latestPayment = await latestPaymentForPhone(phone)
    return {
      ok: true,
      paid,
      grades: subscription?.grades || [],
      plan: subscription?.plan || null,
      subscription,
      latestPayment,
    }
  })
}
