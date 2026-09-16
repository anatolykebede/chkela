export type ReferralPurchase = {
  amountEtb: number
  /** 20% of amountEtb, credited to referrer as CP (not ETB). */
  referrerCp: number
  purchasedAt: string
}

export type ReferralRedemption = {
  inviteePhone: string
  redeemedAt: string
  unlockDays: number
  /** Signup CP granted to the referrer. */
  referrerPoints: number
  /** Signup CP granted to the invitee. */
  inviteePoints: number
  /** Invitee purchase discount percent (typically 10). */
  purchaseDiscountPercent: number
  purchases?: ReferralPurchase[]
}

export type Referral = {
  id: string
  code: string
  referrerPhone: string
  createdAt: string
  creditDaysEarned: number
  /** Cumulative signup CP earned from invites. */
  pointsEarned: number
  /** Cumulative purchase-commission CP earned. */
  purchaseCpEarned: number
  redemptions: ReferralRedemption[]
}

/** Running CP balance keyed by phone (+251…). */
export type ReferralPointBalances = Record<string, number>

export type ReferralsFile = {
  referrals: Referral[]
  pointBalances?: ReferralPointBalances
}

export type ReferralMeResponse = {
  code: string
  link: string
  referrerPhone: string
  inviteCount: number
  creditDaysEarned: number
  pointsEarned: number
  purchaseCpEarned: number
  /** Total CP balance (signup + purchase commissions). */
  cpBalance: number
  /** @deprecated alias of cpBalance */
  pointsBalance: number
  unlockDaysPerInvite: number
  pointsPerInvite: number
  inviteePointsPerRedeem: number
  inviteePurchaseDiscountPercent: number
  referrerPurchaseCpPercent: number
}

export type DiscountLookup =
  | {
      ok: true
      eligible: true
      discountPercent: number
      code: string
      referrerPhone: string
    }
  | {
      ok: true
      eligible: false
      discountPercent: 0
    }
  | { ok: false; error: 'missing_phone' }

export type RedeemResult =
  | {
      ok: true
      code: string
      unlockDays: number
      referrerCreditDays: number
      referrerPoints: number
      inviteePoints: number
      purchaseDiscountPercent: number
    }
  | {
      ok: false
      error:
        | 'invalid'
        | 'missing_phone'
        | 'not_found'
        | 'self_referral'
        | 'already_redeemed'
    }

export type PurchaseResult =
  | {
      ok: true
      amountEtb: number
      referrerCp: number
      referrerPhone: string
      code: string
    }
  | {
      ok: false
      error: 'missing_phone' | 'invalid_amount' | 'not_an_invitee'
    }
