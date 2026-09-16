import { useCallback, useEffect, useState } from 'react'
import { PageHeader } from '../components/PageHeader'
import { Badge } from '../components/Badge'
import {
  listAppUsers,
  listDeletedAppUsers,
  type AppUser,
  type DeletedAppUser,
} from '../lib/usersApi'
import '../components/DataTable.css'
import './Pages.css'

type UsersTab = 'active' | 'deleted'

export function UsersPage() {
  const [tab, setTab] = useState<UsersTab>('active')
  const [users, setUsers] = useState<AppUser[]>([])
  const [deleted, setDeleted] = useState<DeletedAppUser[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const [nextUsers, nextDeleted] = await Promise.all([
        listAppUsers(),
        listDeletedAppUsers(),
      ])
      setUsers(nextUsers)
      setDeleted(nextDeleted)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load users')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  return (
    <div className="page">
      <PageHeader
        title="Users"
        subtitle="Active students and accounts deleted from the app."
        action={
          <button type="button" className="btn-ghost" onClick={() => void load()}>
            Refresh
          </button>
        }
      />

      <div className="users-tabs" role="tablist" aria-label="Users lists">
        <button
          type="button"
          role="tab"
          aria-selected={tab === 'active'}
          className={`users-tab${tab === 'active' ? ' is-active' : ''}`}
          onClick={() => setTab('active')}
        >
          Active ({users.length})
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={tab === 'deleted'}
          className={`users-tab${tab === 'deleted' ? ' is-active' : ''}`}
          onClick={() => setTab('deleted')}
        >
          Deleted ({deleted.length})
        </button>
      </div>

      {error ? <p className="text-muted">{error}</p> : null}

      {tab === 'active' ? (
        <div className="data-table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Phone</th>
                <th>Grade</th>
                <th>Plan</th>
                <th>Onboarding</th>
                <th>Status</th>
                <th>Joined</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={7} className="text-muted">
                    Loading users…
                  </td>
                </tr>
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-muted">
                    No registered users yet. They appear after a successful OTP
                    login.
                  </td>
                </tr>
              ) : (
                users.map((user) => (
                  <tr key={user.id}>
                    <td>{user.name || user.phone}</td>
                    <td className="text-muted">{user.phone}</td>
                    <td>{user.grade || '—'}</td>
                    <td>{user.plan || 'free'}</td>
                    <td>
                      <Badge
                        tone={user.onboardingComplete ? 'success' : 'neutral'}
                      >
                        {user.onboardingComplete ? 'done' : 'pending'}
                      </Badge>
                    </td>
                    <td>
                      <Badge
                        tone={
                          user.status === 'active'
                            ? 'success'
                            : user.status === 'suspended'
                              ? 'danger'
                              : 'neutral'
                        }
                      >
                        {user.status}
                      </Badge>
                    </td>
                    <td className="text-muted">{user.joined || '—'}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="data-table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Phone</th>
                <th>Grade</th>
                <th>Plan</th>
                <th>Joined</th>
                <th>Deleted</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6} className="text-muted">
                    Loading deleted users…
                  </td>
                </tr>
              ) : deleted.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-muted">
                    No deleted accounts yet.
                  </td>
                </tr>
              ) : (
                deleted.map((user) => (
                  <tr key={user.id}>
                    <td>{user.name || user.phone}</td>
                    <td className="text-muted">{user.phone}</td>
                    <td>{user.grade || '—'}</td>
                    <td>{user.plan || 'free'}</td>
                    <td className="text-muted">{user.joined || '—'}</td>
                    <td className="text-muted">{user.deleted || '—'}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
