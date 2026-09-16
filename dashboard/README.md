# Chkela Admin Dashboard

React admin dashboard for managing the Chkela edtech app (Flutter).

## Stack

- React 19 + TypeScript
- Vite
- React Router
- Lucide icons

## Run locally

Start the social backend first (chat, friends, notifications register):

```bash
cd ../server
npm install
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/chkela npm run migrate
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/chkela npm run dev
```

Then run dashboard:

```bash
cd dashboard
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173).  
`/api/chat`, `/api/friends`, and `/api/notifications` are proxied to `http://127.0.0.1:3001`.

## Pages

| Route | Purpose |
|-------|---------|
| `/` | Overview — stats, signups, quick actions |
| `/users` | Student accounts |
| `/subscriptions` | Plans and billing |
| `/payments` | CBE / Chapa payment verification |
| `/content` | Notes, exams, flashcards |
| `/settings` | Pricing, payment accounts, support |

Data is mock for now. Wire to your backend API when ready.

## Build

```bash
npm run build
npm run preview
```
