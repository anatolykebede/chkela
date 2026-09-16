import type { FeedbackEntry } from '../../../shared/feedback/types'
import { adminFetch } from './adminAuth'

export type { FeedbackEntry }

export async function listFeedback(): Promise<FeedbackEntry[]> {
  const response = await adminFetch('/api/feedback')
  const data = (await response.json()) as {
    items?: FeedbackEntry[]
    error?: string
  }
  if (!response.ok) throw new Error(data.error || 'Failed to load feedback')
  return data.items || []
}

export async function setFeedbackStatus(
  id: string,
  status: FeedbackEntry['status'],
): Promise<FeedbackEntry> {
  const response = await adminFetch(`/api/feedback/${encodeURIComponent(id)}/status`, {
    method: 'PATCH',
    body: JSON.stringify({ status }),
  })
  const data = (await response.json()) as {
    item?: FeedbackEntry
    error?: string
  }
  if (!response.ok || !data.item) {
    throw new Error(data.error || 'Failed to update feedback')
  }
  return data.item
}
