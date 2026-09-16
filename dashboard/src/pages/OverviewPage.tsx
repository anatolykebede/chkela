import { Users, CreditCard, Wallet, Activity } from 'lucide-react';
import { StatCard } from '../components/StatCard';
import { PageHeader } from '../components/PageHeader';
import { overviewStats, recentSignups, payments } from '../data/mockData';
import '../components/DataTable.css';
import './Pages.css';

function formatEtb(amount: number) {
  return `${amount.toLocaleString()} ETB`;
}

export function OverviewPage() {
  const pendingCount = payments.filter((p) => p.status === 'pending').length;

  return (
    <div className="page">
      <PageHeader
        title="Overview"
        subtitle="Monitor Chkela app health, growth, and pending actions."
      />

      <div className="stats-grid">
        <StatCard
          label="Total users"
          value={overviewStats.totalUsers.toLocaleString()}
          hint={`${overviewStats.dailyActive.toLocaleString()} active today`}
          icon={Users}
          accent="accent"
        />
        <StatCard
          label="Active subscriptions"
          value={overviewStats.activeSubscriptions.toLocaleString()}
          hint="Grade + bundle plans"
          icon={CreditCard}
          accent="teal"
        />
        <StatCard
          label="Monthly revenue"
          value={formatEtb(overviewStats.monthlyRevenue)}
          hint="Estimated MRR"
          icon={Wallet}
          accent="amber"
        />
        <StatCard
          label="Pending payments"
          value={String(pendingCount)}
          hint="CBE receipts to verify"
          icon={Activity}
          accent="danger"
        />
      </div>

      <div className="page-grid">
        <section className="panel">
          <h2 className="panel__title">Recent signups</h2>
          <ul className="signup-list">
            {recentSignups.map((user) => (
              <li key={user.id} className="signup-list__item">
                <div className="signup-list__avatar">{user.name.charAt(0)}</div>
                <div>
                  <p className="signup-list__name">{user.name}</p>
                  <p className="signup-list__meta">
                    {user.grade} · {user.joined}
                  </p>
                </div>
              </li>
            ))}
          </ul>
        </section>

        <section className="panel">
          <h2 className="panel__title">Quick actions</h2>
          <div className="quick-actions">
            <button type="button" className="quick-actions__btn">
              Verify CBE payments
              <span>{pendingCount} pending</span>
            </button>
            <button type="button" className="quick-actions__btn">
              Publish new content
            </button>
            <button type="button" className="quick-actions__btn">
              Export user report
            </button>
            <button type="button" className="quick-actions__btn">
              Broadcast announcement
            </button>
          </div>
        </section>
      </div>
    </div>
  );
}
