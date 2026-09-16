import { adminFetch } from './adminAuth'

export type AppUserStatus = 'active' | 'inactive' | 'suspended' | 'deleted'

export type AppUser = {
  id: string
  phone: string
  name: string
  displayName: string
  grade: string
  plan: string
  status: AppUserStatus
  onboardingComplete: boolean
  joined: string
  createdAt?: string
  updatedAt?: string
}

export type DeletedAppUser = AppUser & {
  deleted: string
  deletedAt?: string
  registeredAt?: string
}

export async function listAppUsers(): Promise<AppUser[]> {
  const response = await adminFetch('/api/users')
  const data = (await response.json()) as {
    users?: AppUser[]
    error?: string
    message?: string
  }
  if (!response.ok) {
    throw new Error(data.error || data.message || 'Failed to load users')
  }
  return data.users || []
}

export async function listDeletedAppUsers(): Promise<DeletedAppUser[]> {
  const response = await adminFetch('/api/users/deleted')
  const data = (await response.json()) as {
    users?: DeletedAppUser[]
    error?: string
    message?: string
  }
  if (!response.ok) {
    throw new Error(data.error || data.message || 'Failed to load deleted users')
  }
  return data.users || []
}
