import { Bell, LogOut, Search } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { adminLogout } from '../lib/adminAuth';
import './TopBar.css';

export function TopBar() {
  const navigate = useNavigate();

  async function onLogout() {
    await adminLogout();
    navigate('/login', { replace: true });
  }

  return (
    <header className="topbar">
      <div className="topbar__search">
        <Search size={16} />
        <input type="search" placeholder="Search users, payments, content…" />
      </div>
      <div className="topbar__actions">
        <button type="button" className="topbar__icon-btn" aria-label="Notifications">
          <Bell size={18} />
          <span className="topbar__dot" />
        </button>
        <button
          type="button"
          className="topbar__icon-btn"
          aria-label="Sign out"
          onClick={() => void onLogout()}
        >
          <LogOut size={18} />
        </button>
        <div className="topbar__avatar">AD</div>
      </div>
    </header>
  );
}
