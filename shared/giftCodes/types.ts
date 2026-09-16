export type GiftCode = {
  id: string
  code: string
  amountBirr: number
  createdAt: string
  claimedAt: string | null
  /** Phone number of the student who claimed the code */
  claimedBy: string | null
}

export type GiftCodesFile = {
  codes: GiftCode[]
}

export type ClaimResult =
  | { ok: true; amountBirr: number; code: string }
  | {
      ok: false
      error:
        | 'not_found'
        | 'already_claimed'
        | 'invalid'
        | 'missing_phone'
        | 'not_a_student'
    }
