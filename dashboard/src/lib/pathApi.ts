import type { PathCatalog, PathChallenge, PathLevel } from '../../../shared/path/types'
import { adminFetch } from './adminAuth'

export type { PathCatalog, PathChallenge, PathLevel }

async function parseJson<T>(res: Response): Promise<T> {
  const data = (await res.json()) as T & { error?: string }
  if (!res.ok) {
    throw new Error(
      typeof data === 'object' && data && 'error' in data && data.error
        ? String(data.error)
        : `Request failed (${res.status})`,
    )
  }
  return data
}

export async function fetchPathCatalog(): Promise<PathCatalog> {
  const res = await adminFetch('/api/path')
  const data = await parseJson<{ catalog: PathCatalog }>(res)
  return data.catalog
}

export async function fetchPathProgressList(): Promise<unknown[]> {
  const res = await adminFetch('/api/path/progress')
  const data = await parseJson<{ progress: unknown[] }>(res)
  return data.progress
}

export async function upsertPathLevel(
  item: Partial<PathLevel> & { title: string },
): Promise<PathLevel> {
  const res = await adminFetch('/api/path/levels', {
    method: 'POST',
    body: JSON.stringify(item),
  })
  const data = await parseJson<{ item: PathLevel }>(res)
  return data.item
}

export async function upsertPathChallenge(
  item: Partial<PathChallenge> & { levelId: string; type: PathChallenge['type'] },
): Promise<PathChallenge> {
  const res = await adminFetch('/api/path/challenges', {
    method: 'POST',
    body: JSON.stringify(item),
  })
  const data = await parseJson<{ item: PathChallenge }>(res)
  return data.item
}

export async function deletePathItem(
  collection: 'levels' | 'challenges',
  id: string,
): Promise<void> {
  const res = await adminFetch(`/api/path/${collection}/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  })
  await parseJson<{ ok: boolean }>(res)
}
