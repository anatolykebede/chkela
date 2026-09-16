import type { LucideIcon } from 'lucide-react';
import './StatCard.css';

type StatCardProps = {
  label: string;
  value: string;
  hint?: string;
  icon: LucideIcon;
  accent?: 'accent' | 'teal' | 'amber' | 'danger';
};

export function StatCard({
  label,
  value,
  hint,
  icon: Icon,
  accent = 'accent',
}: StatCardProps) {
  return (
    <article className={`stat-card stat-card--${accent}`}>
      <div className="stat-card__icon">
        <Icon size={20} />
      </div>
      <div className="stat-card__body">
        <p className="stat-card__label">{label}</p>
        <p className="stat-card__value">{value}</p>
        {hint ? <p className="stat-card__hint">{hint}</p> : null}
      </div>
    </article>
  );
}
