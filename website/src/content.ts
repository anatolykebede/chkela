export const STORE = {
  appStore: 'https://apps.apple.com/ke/app/chkela/id6738397728',
  playStore: 'https://play.google.com/store/apps/details?id=com.chkela.v1&hl=en',
  web: 'https://www.chkela.com/',
  gift: 'https://t.me/chkelaadmin',
} as const

export const CONTACT = {
  phone: '+251947819388',
  phoneHref: 'tel:+251947819388',
  email: 'contact@chkela.com',
  emailHref: 'mailto:contact@chkela.com',
} as const

export const COPY = {
  hero: {
    brand: 'Chkela',
    headlineBefore: 'Study smarter.',
    headlineAccent: 'Not harder.',
    lead:
      'Stop grinding random notes for hours. Chkela shows what actually moves your matric score — then helps you practice it.',
  },
  features: {
    eyebrow: 'The smarter way',
    title: 'Less wasted time. More marks.',
    lead:
      'Every tool in Chkela is built around one idea: put your energy where it counts for exam day.',
  },
  proof: {
    stat: '90%',
    title: 'of Chkela students passed matric last year.',
    lead:
      'Not because they studied longer — because they studied the right things, with feedback that made every session count.',
  },
  closing: {
    title: 'Work smart. Pass strong.',
    lead:
      'Download Chkela and turn your next study block into progress you can measure — not hours you can’t get back.',
  },
  footer: 'Smarter matric prep for Ethiopian students.',
} as const

export const FEATURES = [
  {
    title: 'Practice what the exam actually asks',
    body: 'Drill real NEAEA and Grade 12 past papers — so your time goes into the question styles that show up on exam day.',
    accent: '#6c63ff',
  },
  {
    title: 'Fix weak spots, skip the rest',
    body: 'See which topics are costing you marks. Double down there instead of re-reading chapters you’ve already got.',
    accent: '#00c896',
  },
  {
    title: 'Short drills that compound',
    body: 'Daily quizzes keep what you learned from slipping away — so progress sticks without marathon cram sessions.',
    accent: '#f5a623',
  },
  {
    title: 'Get unstuck in seconds',
    body: 'When a concept won’t click, ask the in-app tutor and move on. No more losing an evening to one confusing paragraph.',
    accent: '#378add',
  },
  {
    title: 'Notes built for revision',
    body: 'Clear, syllabus-aligned study notes you can open before a quiz or the night before the paper — not a pile of random PDFs.',
    accent: '#ff5c39',
  },
  {
    title: 'Stay accountable with peers',
    body: 'Study rooms keep you consistent. Share problems, compare approaches, and keep the pace when motivation dips.',
    accent: '#a89eff',
  },
] as const
