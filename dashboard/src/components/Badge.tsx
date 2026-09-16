import './Badge.css';

type BadgeTone = 'success' | 'warning' | 'danger' | 'neutral' | 'accent';

type BadgeProps = {
  children: string;
  tone?: BadgeTone;
};

export function Badge({ children, tone = 'neutral' }: BadgeProps) {
  return <span className={`badge badge--${tone}`}>{children}</span>;
}
