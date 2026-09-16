import { useCallback, useEffect, useMemo, useState } from 'react'
import { Users } from 'lucide-react'
import { PageHeader } from '../components/PageHeader'
import { Badge } from '../components/Badge'
import {
  listReferrals,
  type Referral,
  type ReferralBalance,
} from '../lib/referralsApi'
import '../components/DataTable.css'
import './Pages.css'
import './GiftCodesPage.css'

export function ReferralsPage() {
  const [referrals, setReferrals] = useState<Referral[]>([])
  const [balances, setBalances] = useState<ReferralBalance[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const refresh = useCallback(async () => {
    setError('')
    try {
      const next = await listReferrals()
      setReferrals(next.referrals)
      setBalances(next.balances)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load referrals')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const stats = useMemo(() => {
    const codes = referrals.length
    const redemptions = referrals.reduce(
      (sum, item) => sum + (item.redemptions?.length || 0),
      0,
    )
    const cp = balances.reduce(
      (sum, item) => sum + (item.cp ?? item.points ?? 0),
      0,
    )
    const purchaseCp = referrals.reduce(
      (sum, item) => sum + (item.purchaseCpEarned || 0),
      0,
    )
    return { codes, redemptions, cp, purchaseCp }
  }, [referrals, balances])

  const rows = useMemo(() => {
    const flat: Array<{
      code: string
      referrerPhone: string
      inviteePhone: string | null
      redeemedAt: string | null
      unlockDays: number | null
      discountPercent: number | null
      referrerCpSignup: number | null
      inviteeCp: number | null
      purchaseEtb: number | null
      purchaseReferrerCp: number | null
      purchaseCpEarned: number
      createdAt: string
    }> = []

    for (const item of referrals) {
      const redemptions = item.redemptions || []
      if (redemptions.length === 0) {
        flat.push({
          code: item.code,
          referrerPhone: item.referrerPhone,
          inviteePhone: null,
          redeemedAt: null,
          unlockDays: null,
          discountPercent: null,
          referrerCpSignup: null,
          inviteeCp: null,
          purchaseEtb: null,
          purchaseReferrerCp: null,
          purchaseCpEarned: item.purchaseCpEarned || 0,
          createdAt: item.createdAt,
        })
        continue
      }
      for (const redemption of redemptions) {
        const purchases = redemption.purchases || []
        if (purchases.length === 0) {
          flat.push({
            code: item.code,
            referrerPhone: item.referrerPhone,
            inviteePhone: redemption.inviteePhone,
            redeemedAt: redemption.redeemedAt,
            unlockDays: redemption.unlockDays,
            discountPercent: redemption.purchaseDiscountPercent ?? 10,
            referrerCpSignup: redemption.referrerPoints ?? null,
            inviteeCp: redemption.inviteePoints ?? null,
            purchaseEtb: null,
            purchaseReferrerCp: null,
            purchaseCpEarned: item.purchaseCpEarned || 0,
            createdAt: item.createdAt,
          })
          continue
        }
        for (const purchase of purchases) {
          flat.push({
            code: item.code,
            referrerPhone: item.referrerPhone,
            inviteePhone: redemption.inviteePhone,
            redeemedAt: purchase.purchasedAt,
            unlockDays: redemption.unlockDays,
            discountPercent: redemption.purchaseDiscountPercent ?? 10,
            referrerCpSignup: redemption.referrerPoints ?? null,
            inviteeCp: redemption.inviteePoints ?? null,
            purchaseEtb: purchase.amountEtb,
            purchaseReferrerCp: purchase.referrerCp,
            purchaseCpEarned: item.purchaseCpEarned || 0,
            createdAt: item.createdAt,
          })
        }
      }
    }

    return flat.sort((a, b) => {
      const aKey = a.redeemedAt || a.createdAt
      const bKey = b.redeemedAt || b.createdAt
      return bKey.localeCompare(aKey)
    })
  }, [referrals])

  return (
    <div className="page">
      <PageHeader
        title="Referrals"
        subtitle="Invite codes, 10% purchase discount, and 20% referrer CP"
      />

      {error ? (
        <p className="gift-admin-banner gift-admin-banner--error">{error}</p>
      ) : null}

      <div className="gift-admin-stats">
        <div className="gift-admin-stat">
          <span>Codes</span>
          <strong>{stats.codes}</strong>
        </div>
        <div className="gift-admin-stat">
          <span>Redemptions</span>
          <strong>{stats.redemptions}</strong>
        </div>
        <div className="gift-admin-stat">
          <span>Total CP</span>
          <strong>{stats.cp}</strong>
        </div>
        <div className="gift-admin-stat">
          <span>Purchase CP</span>
          <strong>{stats.purchaseCp}</strong>
        </div>
      </div>

      <div className="gift-admin-form" style={{ marginBottom: 16 }}>
        <div className="gift-admin-form__icon">
          <Users size={18} />
        </div>
        <div style={{ flex: 1 }}>
          <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: 14 }}>
            Invitee: <strong>50 CP</strong> + <strong>10% off</strong> purchases
            (no free days). Referrer: <strong>100 CP</strong> on signup, then{' '}
            <strong>20% of purchase amount in CP</strong> (not ETB).
          </p>
        </div>
        <button type="button" className="btn-ghost" onClick={() => void refresh()}>
          Refresh
        </button>
      </div>

      <h3 style={{ margin: '0 0 10px', fontSize: 15 }}>CP balances</h3>
      <div className="data-table-wrap" style={{ marginBottom: 20 }}>
        <table className="data-table">
          <thead>
            <tr>
              <th>Phone</th>
              <th>CP</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={2}>Loading…</td>
              </tr>
            ) : balances.length === 0 ? (
              <tr>
                <td colSpan={2}>No CP yet</td>
              </tr>
            ) : (
              balances.map((row) => (
                <tr key={row.phone}>
                  <td>{row.phone}</td>
                  <td>
                    <strong>{row.cp ?? row.points}</strong> CP
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <h3 style={{ margin: '0 0 10px', fontSize: 15 }}>
        Codes, discounts & purchases
      </h3>
      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>Code</th>
              <th>Referrer</th>
              <th>Invitee</th>
              <th>When</th>
              <th>Discount</th>
              <th>Purchase ETB</th>
              <th>Referrer CP (20%)</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={8}>Loading…</td>
              </tr>
            ) : rows.length === 0 ? (
              <tr>
                <td colSpan={8}>No referral codes yet</td>
              </tr>
            ) : (
              rows.map((row, index) => (
                <tr
                  key={`${row.code}-${row.inviteePhone || 'none'}-${row.redeemedAt || row.createdAt}-${index}`}
                >
                  <td>
                    <code>{row.code}</code>
                  </td>
                  <td>{row.referrerPhone}</td>
                  <td>{row.inviteePhone || '—'}</td>
                  <td>
                    {row.redeemedAt
                      ? new Date(row.redeemedAt).toLocaleString()
                      : '—'}
                  </td>
                  <td>
                    {row.discountPercent != null
                      ? `${row.discountPercent}%`
                      : '—'}
                  </td>
                  <td>
                    {row.purchaseEtb != null ? `ETB ${row.purchaseEtb}` : '—'}
                  </td>
                  <td>
                    {row.purchaseReferrerCp != null
                      ? `${row.purchaseReferrerCp} CP`
                      : '—'}
                  </td>
                  <td>
                    {row.purchaseEtb != null ? (
                      <Badge tone="accent">Purchase</Badge>
                    ) : row.inviteePhone ? (
                      <Badge tone="success">Redeemed</Badge>
                    ) : (
                      <Badge tone="neutral">Unused</Badge>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
