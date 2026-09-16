import { adminFetch } from './adminAuth'

export type PaymentStatus = 'pending' | 'verified' | 'rejected'

export type Payment = {
  id: string
  phone: string
  displayName: string
  method: string
  amount: number
  currency: string
  plan: string
  grades: string[]
  billingPeriod: string
  reference: string
  status: PaymentStatus
  hasReceipt: boolean
  reviewedAt: string | null
  createdAt: string | null
  updatedAt: string | null
}

export async function listPayments(status?: PaymentStatus): Promise<Payment[]> {
  const qs = status ? `?status=${encodeURIComponent(status)}` : ''
  const response = await adminFetch(`/api/payments${qs}`)
  const data = (await response.json()) as {
    payments?: Payment[]
    error?: string
  }
  if (!response.ok) {
    throw new Error(data.error || 'Could not load payments')
  }
  return data.payments || []
}

export async function approvePayment(id: string): Promise<Payment> {
  const response = await adminFetch(`/api/payments/${encodeURIComponent(id)}/approve`, {
    method: 'POST',
    body: JSON.stringify({}),
  })
  const data = (await response.json()) as {
    payment?: Payment
    error?: string
    message?: string
  }
  if (!response.ok || !data.payment) {
    throw new Error(data.error || data.message || 'Approve failed')
  }
  return data.payment
}

export async function rejectPayment(id: string, reason = ''): Promise<Payment> {
  const response = await adminFetch(`/api/payments/${encodeURIComponent(id)}/reject`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
  const data = (await response.json()) as {
    payment?: Payment
    error?: string
    message?: string
  }
  if (!response.ok || !data.payment) {
    throw new Error(data.error || data.message || 'Reject failed')
  }
  return data.payment
}

export function paymentReceiptUrl(id: string): string {
  return `/api/payments/${encodeURIComponent(id)}/receipt`
}

export function formatPaymentWhen(iso: string | null): string {
  if (!iso) return '—'
  const t = Date.parse(iso)
  if (Number.isNaN(t)) return iso
  const diff = Date.now() - t
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins} min ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours} hr ago`
  const days = Math.floor(hours / 24)
  if (days === 1) return 'Yesterday'
  if (days < 7) return `${days} days ago`
  return new Date(t).toLocaleDateString()
}
