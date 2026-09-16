import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Gift, UserPlus } from 'lucide-react'
import { PageHeader } from '../components/PageHeader'
import { Badge } from '../components/Badge'
import {
  createGiftCode,
  listGiftCodes,
  type GiftCode,
} from '../lib/giftCodesApi'
import {
  listStudents,
  upsertStudent,
  type Student,
} from '../lib/studentsApi'
import '../components/DataTable.css'
import './Pages.css'
import './GiftCodesPage.css'

export function GiftCodesPage() {
  const [codes, setCodes] = useState<GiftCode[]>([])
  const [students, setStudents] = useState<Student[]>([])
  const [amount, setAmount] = useState('100')
  const [studentName, setStudentName] = useState('')
  const [studentPhone, setStudentPhone] = useState('')
  const [loading, setLoading] = useState(true)
  const [creating, setCreating] = useState(false)
  const [savingStudent, setSavingStudent] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const refresh = useCallback(async () => {
    setError('')
    try {
      const [nextCodes, nextStudents] = await Promise.all([
        listGiftCodes(),
        listStudents(),
      ])
      setCodes(nextCodes)
      setStudents(nextStudents)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load gift data')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void refresh()
  }, [refresh])

  async function handleGenerate(event: FormEvent) {
    event.preventDefault()
    setCreating(true)
    setError('')
    setNotice('')
    try {
      const created = await createGiftCode(Number(amount))
      setNotice(`Created ${created.code} for ${created.amountBirr} Birr`)
      await refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create code')
    } finally {
      setCreating(false)
    }
  }

  async function handleAddStudent(event: FormEvent) {
    event.preventDefault()
    setSavingStudent(true)
    setError('')
    setNotice('')
    try {
      const student = await upsertStudent({
        name: studentName,
        phone: studentPhone,
        status: 'active',
      })
      setNotice(`Saved student ${student.name} (${student.phone})`)
      setStudentName('')
      setStudentPhone('')
      await refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save student')
    } finally {
      setSavingStudent(false)
    }
  }

  async function copyCode(code: string) {
    try {
      await navigator.clipboard.writeText(code)
      setNotice(`Copied ${code}`)
    } catch {
      setNotice('Could not copy — select the code manually')
    }
  }

  const available = codes.filter((c) => !c.claimedAt).length
  const claimed = codes.length - available
  const activeStudents = students.filter((s) => s.status === 'active').length

  return (
    <div className="page">
      <PageHeader
        title="Gift Codes"
        subtitle="Only active Chkela students can claim. Generate codes, then share them with eligible phones."
      />

      <div className="gift-admin-stats">
        <div className="gift-admin-stat">
          <span>Available codes</span>
          <strong>{available}</strong>
        </div>
        <div className="gift-admin-stat">
          <span>Claimed</span>
          <strong>{claimed}</strong>
        </div>
        <div className="gift-admin-stat">
          <span>Active students</span>
          <strong>{activeStudents}</strong>
        </div>
      </div>

      <form className="gift-admin-form panel" onSubmit={handleGenerate}>
        <div className="gift-admin-form__icon">
          <Gift size={18} />
        </div>
        <div className="gift-admin-form__fields">
          <label htmlFor="gift-amount">Prize amount (Birr)</label>
          <div className="gift-admin-form__row">
            <input
              id="gift-amount"
              type="number"
              min={1}
              step={1}
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              required
            />
            <button type="submit" className="btn-primary" disabled={creating}>
              {creating ? 'Generating…' : 'Generate code'}
            </button>
          </div>
          <p className="gift-admin-form__hint">
            Claim requires a matching active student phone on the marketing site.
          </p>
        </div>
      </form>

      <form className="gift-admin-form panel" onSubmit={handleAddStudent}>
        <div className="gift-admin-form__icon gift-admin-form__icon--student">
          <UserPlus size={18} />
        </div>
        <div className="gift-admin-form__fields">
          <label>Add / update eligible student</label>
          <div className="gift-admin-form__row gift-admin-form__row--wide">
            <input
              type="text"
              value={studentName}
              onChange={(e) => setStudentName(e.target.value)}
              placeholder="Student name"
              required
            />
            <input
              type="tel"
              value={studentPhone}
              onChange={(e) => setStudentPhone(e.target.value)}
              placeholder="09xxxxxxxx or +2519xxxxxxxx"
              required
            />
            <button type="submit" className="btn-primary" disabled={savingStudent}>
              {savingStudent ? 'Saving…' : 'Save student'}
            </button>
          </div>
          <p className="gift-admin-form__hint">
            Demo phones: +251911111111, +251922222222, +251933333333 (active).
          </p>
        </div>
      </form>

      {error ? <p className="gift-admin-banner gift-admin-banner--error">{error}</p> : null}
      {notice ? <p className="gift-admin-banner">{notice}</p> : null}

      <h3 className="gift-admin-section-title">Students eligible for gifts</h3>
      <div className="data-table-wrap" style={{ marginBottom: 20 }}>
        <table className="data-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Phone</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={3} className="text-muted">
                  Loading students…
                </td>
              </tr>
            ) : students.length === 0 ? (
              <tr>
                <td colSpan={3} className="text-muted">
                  No students yet. Add one above.
                </td>
              </tr>
            ) : (
              students.map((student) => (
                <tr key={student.id}>
                  <td>{student.name}</td>
                  <td>
                    <code className="gift-code">{student.phone}</code>
                  </td>
                  <td>
                    <Badge
                      tone={student.status === 'active' ? 'success' : 'neutral'}
                    >
                      {student.status}
                    </Badge>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <h3 className="gift-admin-section-title">Gift codes</h3>
      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>Code</th>
              <th>Amount</th>
              <th>Status</th>
              <th>Created</th>
              <th>Claimed</th>
              <th>Phone</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={7} className="text-muted">
                  Loading codes…
                </td>
              </tr>
            ) : codes.length === 0 ? (
              <tr>
                <td colSpan={7} className="text-muted">
                  No gift codes yet. Generate one above.
                </td>
              </tr>
            ) : (
              codes.map((item) => (
                <tr key={item.id}>
                  <td>
                    <code className="gift-code">{item.code}</code>
                  </td>
                  <td>{item.amountBirr} Birr</td>
                  <td>
                    <Badge tone={item.claimedAt ? 'neutral' : 'success'}>
                      {item.claimedAt ? 'claimed' : 'available'}
                    </Badge>
                  </td>
                  <td className="text-muted">{formatDate(item.createdAt)}</td>
                  <td className="text-muted">
                    {item.claimedAt ? formatDate(item.claimedAt) : '—'}
                  </td>
                  <td className="text-muted">{item.claimedBy || '—'}</td>
                  <td>
                    <div className="data-table__actions">
                      <button
                        type="button"
                        className="btn-ghost"
                        onClick={() => void copyCode(item.code)}
                      >
                        Copy
                      </button>
                    </div>
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

function formatDate(value: string) {
  return new Date(value).toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}
