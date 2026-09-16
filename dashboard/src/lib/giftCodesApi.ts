import type { ClaimResult, GiftCode } from '../../../shared/giftCodes/types'
import { adminFetch } from './adminAuth'

export type { ClaimResult, GiftCode }

export async function listGiftCodes(): Promise<GiftCode[]> {
  const response = await adminFetch('/api/gift-codes')
  const data = (await response.json()) as { codes?: GiftCode[]; error?: string }
  if (!response.ok) throw new Error(data.error || 'Failed to load gift codes')
  return data.codes || []
}

export async function createGiftCode(amountBirr: number): Promise<GiftCode> {
  const response = await adminFetch('/api/gift-codes', {
    method: 'POST',
    body: JSON.stringify({ amountBirr }),
  })
  const data = (await response.json()) as { code?: GiftCode; error?: string }
  if (!response.ok || !data.code) {
    throw new Error(data.error || 'Failed to create gift code')
  }
  return data.code
}
