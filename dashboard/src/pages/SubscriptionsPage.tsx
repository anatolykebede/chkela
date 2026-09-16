import { PageHeader } from '../components/PageHeader';
import { Badge } from '../components/Badge';
import { subscriptions } from '../data/mockData';
import '../components/DataTable.css';
import './Pages.css';

export function SubscriptionsPage() {
  return (
    <div className="page">
      <PageHeader
        title="Subscriptions"
        subtitle="Grade plans (79 ETB) and all-grades bundle (199 ETB)."
        action={<button type="button" className="btn-primary">Grant access</button>}
      />

      <div className="data-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>User</th>
              <th>Plan</th>
              <th>Type</th>
              <th>Amount</th>
              <th>Billing</th>
              <th>Renews</th>
              <th>Status</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {subscriptions.map((sub) => (
              <tr key={sub.id}>
                <td>{sub.user}</td>
                <td>{sub.plan}</td>
                <td>
                  <Badge tone={sub.type === 'bundle' ? 'accent' : 'neutral'}>
                    {sub.type}
                  </Badge>
                </td>
                <td>{sub.amount} ETB</td>
                <td>{sub.period}</td>
                <td className="text-muted">{sub.renews}</td>
                <td>
                  <Badge tone="success">{sub.status}</Badge>
                </td>
                <td>
                  <div className="data-table__actions">
                    <button type="button" className="btn-ghost">Extend</button>
                    <button type="button" className="btn-ghost">Cancel</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
