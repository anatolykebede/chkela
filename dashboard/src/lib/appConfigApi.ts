import type { AppConfig } from '../../../shared/appConfig/types'
import { adminFetch } from './adminAuth'

export type { AppConfig }

export async function fetchAppConfig(): Promise<AppConfig> {
  const response = await adminFetch('/api/app-config')
  const data = (await response.json()) as { config?: AppConfig; error?: string }
  if (!response.ok || !data.config) {
    throw new Error(data.error || 'Failed to load app config')
  }
  return data.config
}

export async function saveAppConfig(config: {
  contact: AppConfig['contact']
  social: AppConfig['social']
}): Promise<AppConfig> {
  const response = await adminFetch('/api/app-config', {
    method: 'PUT',
    body: JSON.stringify({ config }),
  })
  const data = (await response.json()) as { config?: AppConfig; error?: string }
  if (!response.ok || !data.config) {
    throw new Error(data.error || 'Failed to save app config')
  }
  return data.config
}
