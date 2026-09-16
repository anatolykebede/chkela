import { useCallback, useEffect, useMemo, useState } from 'react'
import { PageHeader } from '../components/PageHeader'
import { Badge } from '../components/Badge'
import { getAdminToken } from '../lib/adminAuth'
import {
  approvePayment,
  formatPaymentWhen,
  listPayments,
  paymentReceiptUrl,
  rejectPayment,
  type Payment,
  type PaymentStatus,
} from '../lib/paymentsApi'
import '../components/DataTable.css'
import './Pages.css'
import './GiftCodesPage.css'

function paymentTone(status: PaymentStatus) {
  if (status === 'verified') return 'success'
  if (status === 'pending') return 'warning'
  return 'danger'
}

function displayUser(payment: Payment) {
  const name = payment.displayName?.trim()
  if (name) return name
  return payment.phone || 'Unknown'
}

export function PaymentsPage() {
  const [payments, setPayments] = useState<Payment[]>([])
  const [loading, setLoading] = useState(true)
  const [actingId, setActingId] = useState<string | null>(null)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [filter, setFilter] = useState<'all' | PaymentStatus>('all')

  const refresh = useCallback(async () => {
    setError('')
    try {
      const rows = await listPayments(filter === 'all' ? undefined : filter)
      setPayments(rows)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load payments')
    } finally {
      setLoading(false)
    }
  }, [filter])

  useEffect(() => {
    setLoading(true)
    void refresh()
  }, [refresh])

  const pending = useMemo(
    () => payments.filter((p) => p.status === 'pending').length,
    [payments],
  )

  async function onApprove(payment: Payment) {
    setActingId(payment.id)
    setError('')
    setNotice('')
    try {
      await approvePayment(payment.id)
      setNotice(
        `Approved ${displayUser(payment)} — subscription access granted`,
      )
      await refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Approve failed')
    } finally {
      setActingId(null)
    }
  }

  async function onReject(payment: Payment) {
    const reason = window.prompt('Reject reason (optional)') ?? ''
    setActingId(payment.id)
    setError('')
    setNotice('')
    try {
      await rejectPayment(payment.id, reason)
      setNotice(`Rejected payment from ${displayUser(payment)}`)
      await refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Reject failed')
    } finally {
      setActingId(null)
    }
  }

  function openReceipt(payment: Payment) {
    const token = getAdminToken()
    const url = paymentReceiptUrl(payment.id)
    if (!token) {
      window.open(url, '_blank', 'noopener,noreferrer')
      return
    }
    void fetch(url, { headers: { Authorization: `Bearer ${token}` } })
      .then(async (res) => {
        if (!res.ok) throw new Error('Could not load receipt')
        const blob = await res.blob()
        const objectUrl = URL.createObjectURL(blob)
        window.open(objectUrl, '_blank', 'noopener,noreferrer')
        setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000)
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : 'Could not open receipt')
      })
  }

  return (
    <div className="page">
      <PageHeader
        title="Payments"
        subtitle={
          loading
            ? 'Loading payment queue…'
            : `${pending} receipt${pending === 1 ? '' : 's'} waiting for verification.`
        }
        action={
          <button type="button" className="btn-primary" onClick={() => void refresh()}>
            Refresh
          </button>
        }
      />

      {error ? (
        <p className="gift-admin-banner gift-admin-banner--error">{error}</p>
      ) : null}
      {notice ? <p className="gift-admin-banner">{notice}</p> : null}

      <div className="gift-admin-stats" style={{ marginBottom: 16 }}>
        {(['all', 'pending', 'verified', 'rejected'] as const).map((key) => (
          <button
            key={key}
            type="button"
            className={`btn-ghost${filter === key ? ' is-active' : ''}`}
            onClick={() => setFilter(key)}
            style={{
              borderColor: filter === key ? 'var(--accent, #6c63ff)' : undefined,
            }}
          >
            {key === 'all' ? 'All' : key}
          </button>
        ))}
      </div>

      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>User</th>
              <th>Method</th>
              <th>Amount</th>
              <th>Plan</th>
              <th>Reference</th>
              <th>Submitted</th>
              <th>Status</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={8} className="text-muted">
                  Loading…
                </td>
              </tr>
            ) : payments.length === 0 ? (
              <tr>
                <td colSpan={8} className="text-muted">
                  No payments in this queue yet.
                </td>
              </tr>
            ) : (
              payments.map((payment) => (
                <tr key={payment.id}>
                  <td>
                    <div>{displayUser(payment)}</div>
                    <div className="text-muted" style={{ fontSize: 12 }}>
                      {payment.phone}
                    </div>
                  </td>
                  <td>
                    <Badge tone={payment.method === 'CBE' ? 'accent' : 'success'}>
                      {payment.method}
                    </Badge>
                  </td>
                  <td>
                    {payment.amount} {payment.currency}
                  </td>
                  <td className="text-muted">
                    {payment.plan}
                    {payment.billingPeriod ? ` · ${payment.billingPeriod}` : ''}
                    {payment.grades?.length
                      ? ` · ${payment.grades.join(', ')}`
                      : ''}
                  </td>
                  <td className="text-muted">{payment.reference || '—'}</td>
                  <td className="text-muted">
                    {formatPaymentWhen(payment.createdAt)}
                  </td>
                  <td>
                    <Badge tone={paymentTone(payment.status)}>
                      {payment.status}
                    </Badge>
                  </td>
                  <td>
                    <div className="data-table__actions">
                      {payment.hasReceipt ? (
                        <button
                          type="button"
                          className="btn-ghost"
                          onClick={() => openReceipt(payment)}
                        >
                          Receipt
                        </button>
                      ) : null}
                      {payment.status === 'pending' ? (
                        <>
                          <button
                            type="button"
                            className="btn-ghost"
                            disabled={actingId === payment.id}
                            onClick={() => void onApprove(payment)}
                          >
                            {actingId === payment.id ? '…' : 'Approve'}
                          </button>
                          <button
                            type="button"
                            className="btn-ghost"
                            disabled={actingId === payment.id}
                            onClick={() => void onReject(payment)}
                          >
                            Reject
                          </button>
                        </>
                      ) : null}
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
