import { NavLink, Outlet } from 'react-router-dom'
import { Footer } from './Footer'
import { Nav } from './Nav'
import './SiteLayout.css'

export function SiteLayout() {
  return (
    <div className="site">
      <Nav />
      <main>
        <Outlet />
      </main>
      <Footer />
    </div>
  )
}

export function BrandMark({ className = '' }: { className?: string }) {
  return (
    <NavLink to="/" className={`brand ${className}`}>
      Chkela<i className="brand-dot" aria-hidden />
    </NavLink>
  )
}
