import { CONTACT, COPY } from '../content'
import { BrandMark } from './SiteLayout'
import './Footer.css'

export function Footer() {
  return (
    <footer className="footer">
      <div className="footer-inner">
        <div className="footer-brand">
          <BrandMark />
          <p>{COPY.footer}</p>
        </div>
        <div className="footer-links">
          <a href={CONTACT.phoneHref}>{CONTACT.phone}</a>
          <a href={CONTACT.emailHref}>{CONTACT.email}</a>
        </div>
      </div>
    </footer>
  )
}
