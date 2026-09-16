import { useEffect, useId, useState, type FormEvent } from 'react'
import { claimGiftCode } from '../lib/giftCodesApi'
import './ClaimGiftButton.css'

type Props = {
  className?: string
}

type Stage = 'form' | 'success' | 'error'

export function ClaimGiftButton({ className = '' }: Props) {
  const [open, setOpen] = useState(false)
  const [code, setCode] = useState('')
  const [phone, setPhone] = useState('')
  const [stage, setStage] = useState<Stage>('form')
  const [message, setMessage] = useState('')
  const [prize, setPrize] = useState(0)
  const [submitting, setSubmitting] = useState(false)
  const titleId = useId()

  useEffect(() => {
    if (!open) return
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setOpen(false)
    }
    window.addEventListener('keydown', onKey)
    document.body.style.overflow = 'hidden'
    return () => {
      window.removeEventListener('keydown', onKey)
      document.body.style.overflow = ''
    }
  }, [open])

  function openModal() {
    setOpen(true)
    setStage('form')
    setMessage('')
    setPrize(0)
  }

  function closeModal() {
    setOpen(false)
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setSubmitting(true)
    setMessage('')
    try {
      const result = await claimGiftCode(code, phone)
      if (result.ok) {
        setPrize(result.amountBirr)
        setStage('success')
        setCode('')
        return
      }
      setStage('error')
      setMessage(errorCopy(result.error))
    } catch {
      setStage('error')
      setMessage('Could not reach the gift service. Try again in a moment.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <>
      <button type="button" className={`gift-btn ${className}`} onClick={openModal}>
        <span className="gift-mark" aria-hidden>
          <span className="gift-mark-ring" />
          <span className="gift-mark-core">CG</span>
        </span>
        <span className="gift-copy">
          <strong>Claim your gift</strong>
          <span>Enter your code &amp; phone</span>
        </span>
        <span className="gift-arrow" aria-hidden>
          →
        </span>
      </button>

      {open ? (
        <div className="gift-modal" role="presentation" onClick={closeModal}>
          <div
            className="gift-dialog"
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            onClick={(event) => event.stopPropagation()}
          >
            <button type="button" className="gift-dialog-close" onClick={closeModal} aria-label="Close">
              ×
            </button>

            <div className="gift-dialog-mark" aria-hidden>
              <span className="gift-mark-ring" />
              <span className="gift-mark-core">CG</span>
            </div>

            {stage === 'success' ? (
              <div className="gift-dialog-body">
                <h2 id={titleId}>You claimed your gift</h2>
                <p className="gift-prize">{prize} Birr</p>
                <p>
                  This code is now used. We’ll contact you on{' '}
                  <strong>{phone}</strong> to arrange your prize payout.
                </p>
                <button type="button" className="gift-dialog-primary" onClick={closeModal}>
                  Done
                </button>
              </div>
            ) : (
              <form className="gift-dialog-body" onSubmit={(e) => void handleSubmit(e)}>
                <h2 id={titleId}>Claim your gift</h2>
                <p>
                  Enter your Chkela student phone and gift code. Only registered
                  students can claim — and each code works once.
                </p>

                <label htmlFor="gift-code-input">Gift code</label>
                <input
                  id="gift-code-input"
                  value={code}
                  onChange={(e) => {
                    setCode(e.target.value.toUpperCase())
                    if (stage === 'error') setStage('form')
                  }}
                  placeholder="CHK-XXXX-XXXX"
                  autoComplete="off"
                  spellCheck={false}
                  required
                />

                <label htmlFor="gift-phone-input">Phone number</label>
                <input
                  id="gift-phone-input"
                  type="tel"
                  inputMode="tel"
                  value={phone}
                  onChange={(e) => {
                    setPhone(e.target.value)
                    if (stage === 'error') setStage('form')
                  }}
                  placeholder="09xxxxxxxx or +2519xxxxxxxx"
                  autoComplete="tel"
                  required
                />

                {stage === 'error' && message ? (
                  <p className="gift-dialog-error" role="alert">
                    {message}
                  </p>
                ) : null}

                <button type="submit" className="gift-dialog-primary" disabled={submitting}>
                  {submitting ? 'Checking…' : 'Claim prize'}
                </button>
              </form>
            )}
          </div>
        </div>
      ) : null}
    </>
  )
}

function errorCopy(
  error:
    | 'not_found'
    | 'already_claimed'
    | 'invalid'
    | 'missing_phone'
    | 'not_a_student',
) {
  switch (error) {
    case 'already_claimed':
      return 'This code was already claimed. Ask Chkela for a fresh one.'
    case 'invalid':
      return 'That doesn’t look like a valid code. Check the format and try again.'
    case 'missing_phone':
      return 'Enter a valid phone number so we can send your prize.'
    case 'not_a_student':
      return 'This phone isn’t linked to a Chkela student account. Sign up in the app first, then try again.'
    default:
      return 'We couldn’t find that code. Double-check it and try again.'
  }
}
