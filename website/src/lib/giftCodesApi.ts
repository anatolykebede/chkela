import type { ClaimResult } from '../../../shared/giftCodes/types'

export type { ClaimResult }

export async function claimGiftCode(
  code: string,
  phone: string,
): Promise<ClaimResult> {
  const response = await fetch('/api/gift-codes/claim', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code, phone }),
  })
  return (await response.json()) as ClaimResult
}
