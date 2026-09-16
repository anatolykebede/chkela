import type { Referral } from '../../../shared/referrals/types'
import { adminFetch } from './adminAuth'

export type { Referral }

export type ReferralBalance = {
  phone: string
  points: number
  cp?: number
}

export async function listReferrals(): Promise<{
  referrals: Referral[]
  balances: ReferralBalance[]
}> {
  const response = await adminFetch('/api/referrals')
  const data = (await response.json()) as {
    referrals?: Referral[]
    balances?: ReferralBalance[]
    error?: string
  }
  if (!response.ok) throw new Error(data.error || 'Failed to load referrals')
  return {
    referrals: data.referrals || [],
    balances: data.balances || [],
  }
}
