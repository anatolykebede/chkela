const TOKEN_KEY = 'chkela_admin_token'

export function getAdminToken(): string | null {
  const token = localStorage.getItem(TOKEN_KEY)
  if (!token || !token.trim()) return null
  return token.trim()
}

export function setAdminToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token.trim())
}

export function clearAdminToken() {
  localStorage.removeItem(TOKEN_KEY)
}

export function adminAuthHeaders(json = true): HeadersInit {
  const headers: Record<string, string> = {}
  if (json) headers['Content-Type'] = 'application/json'
  const token = getAdminToken()
  if (token) headers.Authorization = `Bearer ${token}`
  return headers
}

export async function adminFetch(
  input: RequestInfo | URL,
  init: RequestInit = {},
): Promise<Response> {
  const headers = new Headers(init.headers)
  const token = getAdminToken()
  if (token && !headers.has('Authorization')) {
    headers.set('Authorization', `Bearer ${token}`)
  }
  if (init.body && !headers.has('Content-Type') && !(init.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json')
  }
  const response = await fetch(input, { ...init, headers })
  if (response.status === 401) {
    clearAdminToken()
    if (!window.location.pathname.startsWith('/login')) {
      window.location.assign('/login')
    }
  }
  return response
}

export async function adminLogin(password: string): Promise<void> {
  const response = await fetch('/api/admin/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ password }),
  })
  const data = (await response.json().catch(() => ({}))) as {
    ok?: boolean
    token?: string
    error?: string
    message?: string
  }
  if (!response.ok || !data.token) {
    throw new Error(data.error || data.message || 'Sign in failed')
  }
  setAdminToken(data.token)
}

export async function adminLogout(): Promise<void> {
  try {
    await fetch('/api/admin/logout', {
      method: 'POST',
      headers: adminAuthHeaders(),
    })
  } catch {
    // ignore network errors on logout
  }
  clearAdminToken()
}

export async function checkAdminSession(): Promise<boolean> {
  const token = getAdminToken()
  if (!token) return false
  try {
    const response = await fetch('/api/admin/me', {
      headers: adminAuthHeaders(false),
    })
    if (!response.ok) {
      clearAdminToken()
      return false
    }
    return true
  } catch {
    return false
  }
}
