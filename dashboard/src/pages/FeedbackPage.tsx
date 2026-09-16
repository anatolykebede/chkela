import { useCallback, useEffect, useMemo, useState } from 'react'
import { MessageSquare } from 'lucide-react'
import { PageHeader } from '../components/PageHeader'
import { Badge } from '../components/Badge'
import {
  listFeedback,
  setFeedbackStatus,
  type FeedbackEntry,
} from '../lib/feedbackApi'
import '../components/DataTable.css'
import './Pages.css'
import './GiftCodesPage.css'

export function FeedbackPage() {
  const [items, setItems] = useState<FeedbackEntry[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const refresh = useCallback(async () => {
    setError('')
    try {
      setItems(await listFeedback())
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load feedback')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const stats = useMemo(() => {
    const total = items.length
    const unread = items.filter((item) => item.status === 'new').length
    const archived = items.filter((item) => item.status === 'archived').length
    return { total, unread, archived }
  }, [items])

  async function updateStatus(id: string, status: FeedbackEntry['status']) {
    setError('')
    setNotice('')
    try {
      await setFeedbackStatus(id, status)
      setNotice(`Marked as ${status}`)
      await refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not update status')
    }
  }

  return (
    <div className="page">
      <PageHeader
        title="Feedback"
        subtitle="Messages submitted from the Chkela app"
      />

      {error ? (
        <p className="gift-admin-banner gift-admin-banner--error">{error}</p>
      ) : null}
      {notice ? <p className="gift-admin-banner">{notice}</p> : null}

      <div className="gift-admin-stats">
        <div className="gift-admin-stat">
          <span>Total</span>
          <strong>{stats.total}</strong>
        </div>
        <div className="gift-admin-stat">
          <span>New</span>
          <strong>{stats.unread}</strong>
        </div>
        <div className="gift-admin-stat">
          <span>Archived</span>
          <strong>{stats.archived}</strong>
        </div>
      </div>

      <div className="gift-admin-form" style={{ marginBottom: 16 }}>
        <div className="gift-admin-form__icon">
          <MessageSquare size={18} />
        </div>
        <div style={{ flex: 1 }}>
          <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: 14 }}>
            Feedback from Account → Feedback is stored here for the admin team.
          </p>
        </div>
        <button type="button" className="btn-ghost" onClick={() => void refresh()}>
          Refresh
        </button>
      </div>

      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>When</th>
              <th>Phone</th>
              <th>Message</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={5}>Loading…</td>
              </tr>
            ) : items.length === 0 ? (
              <tr>
                <td colSpan={5}>No feedback yet</td>
              </tr>
            ) : (
              items.map((item) => (
                <tr key={item.id}>
                  <td>{new Date(item.createdAt).toLocaleString()}</td>
                  <td>{item.phone || '—'}</td>
                  <td style={{ maxWidth: 420, whiteSpace: 'pre-wrap' }}>
                    {item.message}
                  </td>
                  <td>
                    <Badge
                      tone={
                        item.status === 'new'
                          ? 'accent'
                          : item.status === 'read'
                            ? 'success'
                            : 'neutral'
                      }
                    >
                      {item.status}
                    </Badge>
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                      {item.status !== 'read' ? (
                        <button
                          type="button"
                          className="btn-ghost"
                          onClick={() => void updateStatus(item.id, 'read')}
                        >
                          Mark read
                        </button>
                      ) : null}
                      {item.status !== 'archived' ? (
                        <button
                          type="button"
                          className="btn-ghost"
                          onClick={() => void updateStatus(item.id, 'archived')}
                        >
                          Archive
                        </button>
                      ) : null}
                      {item.status !== 'new' ? (
                        <button
                          type="button"
                          className="btn-ghost"
                          onClick={() => void updateStatus(item.id, 'new')}
                        >
                          Mark new
                        </button>
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
