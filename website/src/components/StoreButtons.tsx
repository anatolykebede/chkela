import { STORE } from '../content'
import './StoreButtons.css'

type Props = {
  compact?: boolean
  className?: string
}

export function StoreButtons({ compact = false, className = '' }: Props) {
  return (
    <div className={`store-row ${compact ? 'store-row--compact' : ''} ${className}`}>
      <a
        className="store-btn store-btn--primary"
        href={STORE.appStore}
        target="_blank"
        rel="noreferrer"
        aria-label="Download on the App Store"
      >
        <AppleIcon />
        <span>{compact ? 'App Store' : 'App Store'}</span>
      </a>
      <a
        className="store-btn store-btn--primary"
        href={STORE.playStore}
        target="_blank"
        rel="noreferrer"
        aria-label="Get it on Google Play"
      >
        <PlayIcon />
        <span>{compact ? 'Google Play' : 'Google Play'}</span>
      </a>
    </div>
  )
}

function AppleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M16.37 12.64c.03 3.18 2.79 4.24 2.82 4.25-.02.07-.44 1.51-1.46 2.99-.88 1.28-1.79 2.55-3.22 2.58-1.41.03-1.86-.83-3.48-.83-1.61 0-2.11.81-3.44.86-1.38.05-2.43-1.38-3.32-2.65-1.82-2.62-3.21-7.4-1.34-10.63.93-1.6 2.59-2.61 4.39-2.64 1.37-.03 2.66.92 3.48.92.82 0 2.36-1.14 3.98-.97.68.03 2.58.27 3.8 2.07-.1.06-2.27 1.33-2.21 3.95ZM14.6 4.74c.74-.9 1.24-2.14 1.1-3.38-1.07.04-2.36.71-3.13 1.61-.69.79-1.29 2.06-1.13 3.27 1.19.09 2.41-.61 3.16-1.5Z" />
    </svg>
  )
}

function PlayIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M3.6 2.25c-.37.2-.6.6-.6 1.04v17.42c0 .44.23.84.6 1.04l.1.05 10.07-10.07v-.46L3.7 2.2l-.1.05Zm11.12 6.4-2.3 2.3 2.3 2.3 5.1-2.92c.54-.31.54-1.06 0-1.37l-5.1-2.31ZM12.07 12.3 4.37 20l9.35-5.35-1.65-2.35Zm0-.6 1.65-2.35L4.37 4l7.7 7.7Z" />
    </svg>
  )
}
