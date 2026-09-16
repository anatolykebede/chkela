import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { PageHeader } from '../components/PageHeader'
import { fetchAppConfig, saveAppConfig, type AppConfig } from '../lib/appConfigApi'
import './Pages.css'
import './GiftCodesPage.css'

const emptyContact: AppConfig['contact'] = {
  supportEmail: '',
  supportPhoneDisplay: '',
  supportPhoneTel: '',
  website: '',
  telegramUsername: '',
}

const emptySocial: AppConfig['social'] = {
  instagramUrl: '',
  tiktokUrl: '',
  youtubeUrl: '',
  facebookUrl: '',
  xUrl: '',
}

export function SettingsPage() {
  const [contact, setContact] = useState(emptyContact)
  const [social, setSocial] = useState(emptySocial)
  const [updatedAt, setUpdatedAt] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const refresh = useCallback(async () => {
    setError('')
    try {
      const config = await fetchAppConfig()
      setContact(config.contact)
      setSocial(config.social)
      setUpdatedAt(config.updatedAt)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load settings')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void refresh()
  }, [refresh])

  async function handleSave(event: FormEvent) {
    event.preventDefault()
    setSaving(true)
    setError('')
    setNotice('')
    try {
      const saved = await saveAppConfig({ contact, social })
      setContact(saved.contact)
      setSocial(saved.social)
      setUpdatedAt(saved.updatedAt)
      setNotice(
        'Saved. The app picks this up on next open/refresh — no app store update needed.',
      )
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save settings')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="page">
      <PageHeader
        title="Settings"
        subtitle="Contact and social links shown in the app (live from API)."
      />

      {error ? (
        <p className="gift-admin-banner gift-admin-banner--error">{error}</p>
      ) : null}
      {notice ? <p className="gift-admin-banner">{notice}</p> : null}
      {updatedAt ? (
        <p style={{ color: 'var(--text-muted)', fontSize: 12, marginTop: -8 }}>
          Last saved {new Date(updatedAt).toLocaleString()}
        </p>
      ) : null}

      {loading ? (
        <p>Loading…</p>
      ) : (
        <form className="settings-grid" onSubmit={handleSave}>
          <section className="panel settings-card">
            <h2 className="panel__title">Support & contact</h2>
            <label className="field">
              <span>Telegram username (no @)</span>
              <input
                type="text"
                value={contact.telegramUsername}
                onChange={(e) =>
                  setContact((c) => ({ ...c, telegramUsername: e.target.value }))
                }
              />
            </label>
            <label className="field">
              <span>Support email</span>
              <input
                type="email"
                value={contact.supportEmail}
                onChange={(e) =>
                  setContact((c) => ({ ...c, supportEmail: e.target.value }))
                }
              />
            </label>
            <label className="field">
              <span>Phone (display)</span>
              <input
                type="text"
                value={contact.supportPhoneDisplay}
                onChange={(e) =>
                  setContact((c) => ({
                    ...c,
                    supportPhoneDisplay: e.target.value,
                  }))
                }
              />
            </label>
            <label className="field">
              <span>Phone (tel link)</span>
              <input
                type="text"
                value={contact.supportPhoneTel}
                onChange={(e) =>
                  setContact((c) => ({ ...c, supportPhoneTel: e.target.value }))
                }
              />
            </label>
            <label className="field">
              <span>Website</span>
              <input
                type="url"
                value={contact.website}
                onChange={(e) =>
                  setContact((c) => ({ ...c, website: e.target.value }))
                }
              />
            </label>
          </section>

          <section className="panel settings-card">
            <h2 className="panel__title">Social media</h2>
            <label className="field">
              <span>Instagram URL</span>
              <input
                type="url"
                value={social.instagramUrl}
                onChange={(e) =>
                  setSocial((s) => ({ ...s, instagramUrl: e.target.value }))
                }
              />
            </label>
            <label className="field">
              <span>TikTok URL</span>
              <input
                type="url"
                value={social.tiktokUrl}
                onChange={(e) =>
                  setSocial((s) => ({ ...s, tiktokUrl: e.target.value }))
                }
              />
            </label>
            <label className="field">
              <span>YouTube URL</span>
              <input
                type="url"
                value={social.youtubeUrl}
                onChange={(e) =>
                  setSocial((s) => ({ ...s, youtubeUrl: e.target.value }))
                }
              />
            </label>
            <label className="field">
              <span>Facebook URL</span>
              <input
                type="url"
                value={social.facebookUrl}
                onChange={(e) =>
                  setSocial((s) => ({ ...s, facebookUrl: e.target.value }))
                }
              />
            </label>
            <label className="field">
              <span>X URL</span>
              <input
                type="url"
                value={social.xUrl}
                onChange={(e) =>
                  setSocial((s) => ({ ...s, xUrl: e.target.value }))
                }
              />
            </label>
          </section>

          <div style={{ gridColumn: '1 / -1' }}>
            <button type="submit" className="btn-primary settings-save" disabled={saving}>
              {saving ? 'Saving…' : 'Save contact & social links'}
            </button>
          </div>
        </form>
      )}
    </div>
  )
}
