import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  Users,
  CreditCard,
  Wallet,
  BookOpen,
  Gift,
  UserPlus,
  MessageSquare,
  Bell,
  Settings,
  Map,
} from 'lucide-react';
import './Sidebar.css';

const navItems = [
  { to: '/', label: 'Overview', icon: LayoutDashboard, end: true },
  { to: '/users', label: 'Users', icon: Users },
  { to: '/subscriptions', label: 'Subscriptions', icon: CreditCard },
  { to: '/payments', label: 'Payments', icon: Wallet },
  { to: '/content', label: 'Content', icon: BookOpen },
  { to: '/the-path', label: 'The Path', icon: Map },
  { to: '/gift-codes', label: 'Gift Codes', icon: Gift },
  { to: '/referrals', label: 'Referrals', icon: UserPlus },
  { to: '/feedback', label: 'Feedback', icon: MessageSquare },
  { to: '/notifications', label: 'Notifications', icon: Bell },
  { to: '/settings', label: 'Settings', icon: Settings },
];

export function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="sidebar__brand">
        <div className="sidebar__logo">C</div>
        <div>
          <p className="sidebar__name">Chkela</p>
          <p className="sidebar__tag">Admin</p>
        </div>
      </div>

      <nav className="sidebar__nav">
        {navItems.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) =>
              `sidebar__link${isActive ? ' sidebar__link--active' : ''}`
            }
          >
            <Icon size={18} />
            <span>{label}</span>
          </NavLink>
        ))}
      </nav>

      <div className="sidebar__footer">
        <p className="sidebar__footer-label">App version</p>
        <p className="sidebar__footer-value">1.0.0</p>
      </div>
    </aside>
  );
}
