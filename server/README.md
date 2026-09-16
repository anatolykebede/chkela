# Chkela Social API (Postgres)

Dedicated backend for chat, friends, and push token registration.

## What moved here

- `/api/chat/*`
- `/api/friends/*`
- `/api/notifications/register` (+ social push send/status/list)

This replaces JSON-file writes for social traffic and is safe for concurrent users.

## Requirements

- Node 20+
- Postgres 14+
- `DATABASE_URL` env var
- Optional FCM service account file for push sending

## Quick start

```bash
cd server
npm install
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/chkela npm run migrate
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/chkela npm run dev
```

Server defaults to `http://0.0.0.0:3001`.

Health check: `GET /health`

## Environment

- `DATABASE_URL` required
- `PORT` optional (default `3001`)
- `HOST` optional (default `0.0.0.0`)
- `PG_POOL_MAX` optional (default `20`)
- `FCM_SERVICE_ACCOUNT_PATH` optional path to Firebase Admin JSON

## Migration source files

`npm run migrate` imports from:

- `shared/friends/data.json`
- `shared/chat/data.json`
- `shared/notifications/data.json`

It is idempotent via upserts.

## VPS deployment notes

1. Install Postgres and create DB + user.
2. Run `npm ci && npm run migrate`.
3. Run with systemd or pm2: `node src/index.mjs`.
4. Reverse proxy:
   - `/api/chat`, `/api/friends`, `/api/notifications` -> `:3001`
   - everything else can continue to dashboard/Vite stack.

