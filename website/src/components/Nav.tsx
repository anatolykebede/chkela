import { useEffect, useState } from 'react'
import { NavLink } from 'react-router-dom'
import { BrandMark } from './SiteLayout'
import { StoreButtons } from './StoreButtons'
import './Nav.css'

export function Nav() {
  const [scrolled, setScrolled] = useState(false)
  const [open, setOpen] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  useEffect(() => {
    document.body.style.overflow = open ? 'hidden' : ''
    return () => {
      document.body.style.overflow = ''
    }
  }, [open])

  const close = () => setOpen(false)

  return (
    <header className={`nav ${scrolled ? 'nav--scrolled' : ''} ${open ? 'nav--open' : ''}`}>
      <div className="nav-inner">
        <BrandMark />
        <nav className="nav-links" aria-label="Primary">
          <NavLink to="/" end onClick={close}>
            Home
          </NavLink>
          <a href="/#features" onClick={close}>
            Features
          </a>
          <NavLink to="/about" onClick={close}>
            About
          </NavLink>
        </nav>
        <div className="nav-cta">
          <a
            className="store-btn store-btn--primary store-btn--nav"
            href="https://apps.apple.com/ke/app/chkela/id6738397728"
            target="_blank"
            rel="noreferrer"
          >
            Download
          </a>
        </div>
        <button
          type="button"
          className="nav-burger"
          aria-label={open ? 'Close menu' : 'Open menu'}
          aria-expanded={open}
          onClick={() => setOpen((v) => !v)}
        >
          <span />
          <span />
        </button>
      </div>
      <div className="nav-drawer" hidden={!open}>
        <NavLink to="/" end onClick={close}>
          Home
        </NavLink>
        <a href="/#features" onClick={close}>
          Features
        </a>
        <NavLink to="/about" onClick={close}>
          About
        </NavLink>
        <StoreButtons />
      </div>
    </header>
  )
}
