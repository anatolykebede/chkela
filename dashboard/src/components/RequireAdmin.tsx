import { useEffect, useState } from 'react'
import { Navigate, Outlet } from 'react-router-dom'
import { checkAdminSession } from '../lib/adminAuth'

export function RequireAdmin() {
  const [ready, setReady] = useState(false)
  const [ok, setOk] = useState(false)

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      const valid = await checkAdminSession()
      if (!cancelled) {
        setOk(valid)
        setReady(true)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [])

  if (!ready) {
    return (
      <div style={{ padding: 40, color: 'var(--text-secondary)' }}>
        Checking admin session…
      </div>
    )
  }

  if (!ok) return <Navigate to="/login" replace />
  return <Outlet />
}
