import type { FormEvent } from 'react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { Bell } from 'lucide-react'
import { PageHeader } from '../components/PageHeader'
import { Badge } from '../components/Badge'
import { adminFetch } from '../lib/adminAuth'
import '../components/DataTable.css'
import './Pages.css'
import './GiftCodesPage.css'

type DeviceToken = {
  token: string
  phone: string | null
  platform: string
  updatedAt: string
}

type PushMessage = {
  id: string
  title: string
  body: string
  phone: string | null
  phones?: string[] | null
  audience?: string | null
  topic: string | null
  createdAt: string
  status: string
  successCount: number
  failureCount: number
  error: string | null
  targetCount?: number
}

type Status = {
  fcmReady: boolean
  tokenCount: number
}

type Audience = {
  id: string
  label: string
  description: string
  deviceCount: number
  phoneCount: number
}

export function NotificationsPage() {
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [phone, setPhone] = useState('')
  const [audience, setAudience] = useState('all')
  const [tokens, setTokens] = useState<DeviceToken[]>([])
  const [messages, setMessages] = useState<PushMessage[]>([])
  const [audiences, setAudiences] = useState<Audience[]>([])
  const [status, setStatus] = useState<Status | null>(null)
  const [loading, setLoading] = useState(true)
  const [sending, setSending] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [paidPhone, setPaidPhone] = useState('')
  const [savingPaid, setSavingPaid] = useState(false)

  const selectedAudience = useMemo(
    () => audiences.find((item) => item.id === audience) || null,
    [audiences, audience],
  )

  const refresh = useCallback(async () => {
    setError('')
    try {
      const [statusRes, tokensRes, messagesRes, audiencesRes] =
        await Promise.all([
          adminFetch('/api/notifications/status'),
          adminFetch('/api/notifications/tokens'),
          adminFetch('/api/notifications'),
          adminFetch('/api/notifications/audiences'),
        ])
      const statusData = (await statusRes.json()) as Status
      const tokensData = (await tokensRes.json()) as { tokens?: DeviceToken[] }
      const messagesData = (await messagesRes.json()) as {
        messages?: PushMessage[]
      }
      const audiencesData = (await audiencesRes.json()) as {
        audiences?: Audience[]
      }
      setStatus(statusData)
      setTokens(tokensData.tokens || [])
      setMessages(messagesData.messages || [])
      setAudiences(audiencesData.audiences || [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load notifications')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void refresh()
  }, [refresh])

  async function handleSend(event: FormEvent) {
    event.preventDefault()
    setSending(true)
    setError('')
    setNotice('')
    try {
      const payload =
        audience === 'phone'
          ? {
              title,
              body,
              phone: phone.trim() || undefined,
              audience: phone.trim() ? 'phone' : 'all',
            }
          : {
              title,
              body,
              audience,
            }

      const response = await adminFetch('/api/notifications/send', {
        method: 'POST',
        body: JSON.stringify(payload),
      })
      const data = (await response.json()) as {
        message?: PushMessage
        audience?: { deviceCount?: number }
        error?: string
      }
      if (!response.ok || !data.message) {
        throw new Error(data.error || 'Send failed')
      }
      const count =
        data.message.targetCount ??
        data.audience?.deviceCount ??
        data.message.successCount
      setNotice(
        data.message.status === 'sent'
          ? `Sent to ${count} device(s) (${data.message.successCount} ok / ${data.message.failureCount} failed)`
          : data.message.error || `Saved as ${data.message.status}`,
      )
      setTitle('')
      setBody('')
      await refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Send failed')
    } finally {
      setSending(false)
    }
  }

  async function markPaid(event: FormEvent) {
    event.preventDefault()
    if (!paidPhone.trim()) return
    setSavingPaid(true)
    setError('')
    setNotice('')
    try {
      const response = await adminFetch('/api/subscriptions', {
        method: 'POST',
        body: JSON.stringify({
          phone: paidPhone.trim(),
          plan: 'plus',
          status: 'active',
        }),
      })
      const data = (await response.json()) as {
        subscription?: { phone: string }
        error?: string
      }
      if (!response.ok || !data.subscription) {
        throw new Error(data.error || 'Could not save subscription')
      }
      setNotice(`Marked ${data.subscription.phone} as paid`)
      setPaidPhone('')
      await refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save subscription')
    } finally {
      setSavingPaid(false)
    }
  }

  return (
    <div className="page">
      <PageHeader
        title="Notifications"
        subtitle="Send FCM push notifications to students and audience groups"
      />

      {error ? (
        <p className="gift-admin-banner gift-admin-banner--error">{error}</p>
      ) : null}
      {notice ? <p className="gift-admin-banner">{notice}</p> : null}

      <div className="gift-admin-stats">
        <div className="gift-admin-stat">
          <span>Devices</span>
          <strong>{status?.tokenCount ?? 0}</strong>
        </div>
        <div className="gift-admin-stat">
          <span>FCM server</span>
          <strong>{status?.fcmReady ? 'Ready' : 'Setup needed'}</strong>
        </div>
        <div className="gift-admin-stat">
          <span>Sent log</span>
          <strong>{messages.length}</strong>
        </div>
        <div className="gift-admin-stat">
          <span>Selected group</span>
          <strong>{selectedAudience?.deviceCount ?? (audience === 'phone' ? '—' : 0)}</strong>
        </div>
      </div>

      {!status?.fcmReady ? (
        <p className="gift-admin-banner">
          Add <code>shared/notifications/serviceAccount.json</code> from Firebase
          to deliver real pushes. See <code>shared/notifications/SETUP.md</code>.
          You can still compose messages — they save as stored_only until FCM is ready.
        </p>
      ) : null}

      <form className="gift-admin-form" onSubmit={handleSend} style={{ marginBottom: 20 }}>
        <div className="gift-admin-form__icon">
          <Bell size={18} />
        </div>
        <div style={{ flex: 1, display: 'grid', gap: 10 }}>
          <label className="field">
            <span>Audience</span>
            <select
              value={audience}
              onChange={(e) => setAudience(e.target.value)}
            >
              {audiences.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.label} ({item.deviceCount})
                </option>
              ))}
              <option value="phone">Single phone…</option>
            </select>
            {selectedAudience ? (
              <small style={{ color: 'var(--text-muted, #9aa3b5)' }}>
                {selectedAudience.description}. Reachable now:{' '}
                <strong>{selectedAudience.deviceCount}</strong> device
                {selectedAudience.deviceCount === 1 ? '' : 's'}.
                {selectedAudience.deviceCount === 0
                  ? ' Nobody in this group has an app push token yet.'
                  : ' Only phones that opened the app and allowed notifications are included.'}
              </small>
            ) : audience === 'phone' ? (
              <small style={{ color: 'var(--text-muted, #9aa3b5)' }}>
                Send to one phone, or leave phone empty for all registered devices
              </small>
            ) : null}
          </label>
          <label className="field">
            <span>Title</span>
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Exam reminder"
              required
            />
          </label>
          <label className="field">
            <span>Body</span>
            <textarea
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Your Math battle starts in 10 minutes"
              rows={3}
              required
            />
          </label>
          {audience === 'phone' ? (
            <label className="field">
              <span>Phone (optional — leave empty for all registered devices)</span>
              <input
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="+2519…"
              />
            </label>
          ) : null}
        </div>
        <button type="submit" className="btn-primary" disabled={sending}>
          {sending ? 'Sending…' : 'Send'}
        </button>
      </form>

      <form className="gift-admin-form" onSubmit={markPaid} style={{ marginBottom: 20 }}>
        <div style={{ flex: 1, display: 'grid', gap: 10 }}>
          <label className="field">
            <span>Mark phone as paid (for Paid / Unpaid groups)</span>
            <input
              value={paidPhone}
              onChange={(e) => setPaidPhone(e.target.value)}
              placeholder="+2519…"
            />
          </label>
        </div>
        <button type="submit" className="btn-ghost" disabled={savingPaid}>
          {savingPaid ? 'Saving…' : 'Mark paid'}
        </button>
      </form>

      <h3 style={{ margin: '0 0 10px', fontSize: 15 }}>Audience groups</h3>
      <div className="data-table-wrap" style={{ marginBottom: 20 }}>
        <table className="data-table">
          <thead>
            <tr>
              <th>Group</th>
              <th>Devices</th>
              <th>Description</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={4}>Loading…</td>
              </tr>
            ) : audiences.length === 0 ? (
              <tr>
                <td colSpan={4}>No audiences</td>
              </tr>
            ) : (
              audiences.map((item) => (
                <tr key={item.id}>
                  <td>{item.label}</td>
                  <td>{item.deviceCount}</td>
                  <td>{item.description}</td>
                  <td>
                    <button
                      type="button"
                      className="btn-ghost"
                      onClick={() => setAudience(item.id)}
                    >
                      Use
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <h3 style={{ margin: '0 0 10px', fontSize: 15 }}>Recent sends</h3>
      <div className="data-table-wrap" style={{ marginBottom: 20 }}>
        <table className="data-table">
          <thead>
            <tr>
              <th>When</th>
              <th>Title</th>
              <th>Audience</th>
              <th>Status</th>
              <th>Result</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={5}>Loading…</td>
              </tr>
            ) : messages.length === 0 ? (
              <tr>
                <td colSpan={5}>No notifications yet</td>
              </tr>
            ) : (
              messages.map((item) => (
                <tr key={item.id}>
                  <td>{new Date(item.createdAt).toLocaleString()}</td>
                  <td>
                    <div>{item.title}</div>
                    <div style={{ opacity: 0.7, fontSize: 12 }}>{item.body}</div>
                  </td>
                  <td>
                    {item.audience ||
                      item.phone ||
                      (item.phones?.length ? `${item.phones.length} phones` : 'all')}
                  </td>
                  <td>
                    <Badge
                      tone={
                        item.status === 'sent'
                          ? 'success'
                          : item.status === 'failed'
                            ? 'danger'
                            : 'neutral'
                      }
                    >
                      {item.status}
                    </Badge>
                  </td>
                  <td>
                    {item.status === 'sent'
                      ? `${item.successCount} ok / ${item.failureCount} fail`
                      : item.error || '—'}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <h3 style={{ margin: '0 0 10px', fontSize: 15 }}>Registered devices</h3>
      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>Phone</th>
              <th>Platform</th>
              <th>Updated</th>
              <th>Token</th>
            </tr>
          </thead>
          <tbody>
            {tokens.length === 0 ? (
              <tr>
                <td colSpan={4}>No devices registered yet</td>
              </tr>
            ) : (
              tokens.map((item) => (
                <tr key={item.token}>
                  <td>
                    {item.phone ? (
                      <button
                        type="button"
                        className="btn-ghost"
                        style={{ padding: 0, font: 'inherit', color: 'inherit' }}
                        onClick={() => {
                          setAudience('phone')
                          setPhone(item.phone || '')
                          setNotice(`Target set to ${item.phone}`)
                        }}
                        title="Use this phone as send target"
                      >
                        {item.phone}
                      </button>
                    ) : (
                      '—'
                    )}
                  </td>
                  <td>{item.platform}</td>
                  <td>{new Date(item.updatedAt).toLocaleString()}</td>
                  <td>
                    <code style={{ fontSize: 11 }}>
                      {item.token.slice(0, 18)}…
                    </code>
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
