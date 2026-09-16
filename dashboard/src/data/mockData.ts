export type UserStatus = 'active' | 'inactive' | 'suspended';
export type PaymentStatus = 'pending' | 'verified' | 'rejected';
export type PlanType = 'grade' | 'bundle';

export const overviewStats = {
  totalUsers: 12840,
  activeSubscriptions: 3216,
  monthlyRevenue: 487_200,
  pendingPayments: 24,
  dailyActive: 2840,
  avgStreak: 9.4,
};

export const recentSignups = [
  { id: '1', name: 'Hanna B.', grade: 'Grade 10', joined: '2 min ago' },
  { id: '2', name: 'Daniel M.', grade: 'Grade 11', joined: '18 min ago' },
  { id: '3', name: 'Meron A.', grade: 'Grade 10', joined: '1 hr ago' },
  { id: '4', name: 'Yonas K.', grade: 'Grade 12', joined: '2 hr ago' },
];

export const users = [
  {
    id: 'u1',
    name: 'Selam Tadesse',
    email: 'selam@example.com',
    grade: 'Grade 10',
    plan: 'Grade plan',
    status: 'active' as UserStatus,
    streak: 14,
    joined: '2025-11-02',
  },
  {
    id: 'u2',
    name: 'Hanna B.',
    email: 'hanna@example.com',
    grade: 'Grade 10',
    plan: 'All grades',
    status: 'active' as UserStatus,
    streak: 21,
    joined: '2025-09-14',
  },
  {
    id: 'u3',
    name: 'Daniel M.',
    email: 'daniel@example.com',
    grade: 'Grade 11',
    plan: 'Grade plan',
    status: 'active' as UserStatus,
    streak: 7,
    joined: '2025-10-20',
  },
  {
    id: 'u4',
    name: 'Meron A.',
    email: 'meron@example.com',
    grade: 'Grade 10',
    plan: 'Grade plan',
    status: 'inactive' as UserStatus,
    streak: 0,
    joined: '2025-08-05',
  },
];

export const subscriptions = [
  {
    id: 's1',
    user: 'Selam Tadesse',
    plan: 'Grade 10',
    type: 'grade' as PlanType,
    amount: 79,
    period: 'Monthly',
    renews: '2026-04-08',
    status: 'active',
  },
  {
    id: 's2',
    user: 'Hanna B.',
    plan: 'All grades',
    type: 'bundle' as PlanType,
    amount: 199,
    period: '6 months',
    renews: '2026-08-01',
    status: 'active',
  },
  {
    id: 's3',
    user: 'Daniel M.',
    plan: 'Grade 11',
    type: 'grade' as PlanType,
    amount: 474,
    period: 'Yearly',
    renews: '2027-01-15',
    status: 'active',
  },
];

export const payments = [
  {
    id: 'p1',
    user: 'Yonas K.',
    method: 'CBE',
    amount: 199,
    reference: '—',
    status: 'pending' as PaymentStatus,
    submitted: '5 min ago',
  },
  {
    id: 'p2',
    user: 'Almaz T.',
    method: 'Chapa',
    amount: 79,
    reference: 'CHP-92831',
    status: 'verified' as PaymentStatus,
    submitted: '1 hr ago',
  },
  {
    id: 'p3',
    user: 'Bereket H.',
    method: 'CBE',
    amount: 426,
    reference: '—',
    status: 'pending' as PaymentStatus,
    submitted: '3 hr ago',
  },
  {
    id: 'p4',
    user: 'Sara N.',
    method: 'CBE',
    amount: 79,
    reference: '—',
    status: 'rejected' as PaymentStatus,
    submitted: 'Yesterday',
  },
];

export const contentItems = [
  { id: 'c1', title: 'Quadratic Equations', subject: 'Math', grade: 'Grade 10', type: 'Notes', updated: '2026-03-01' },
  { id: 'c2', title: 'Cell Structure', subject: 'Biology', grade: 'Grade 9', type: 'Flashcards', updated: '2026-02-28' },
  { id: 'c3', title: 'National Exam 2018', subject: 'Physics', grade: 'Grade 12', type: 'Exam', updated: '2026-02-25' },
  { id: 'c4', title: 'Organic Chemistry Intro', subject: 'Chemistry', grade: 'Grade 11', type: 'Video', updated: '2026-02-20' },
];
