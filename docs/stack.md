# Stack

Everything OpenReply needs to run, in one place: the application libraries,
runtime processes, and hosting layout. For setup, see
[deploy-vercel-render.md](deploy-vercel-render.md) and [setup.md](setup.md).

## Application

| Layer | Tool |
| --- | --- |
| Framework | Next.js 16 (App Router, Turbopack) + React 19 |
| Language | TypeScript 5 |
| ORM / DB | Prisma 7 with the `@prisma/adapter-pg` driver, PostgreSQL |
| Queue | BullMQ 5 on Redis, via `ioredis` |
| Auth | Auth.js / NextAuth 5 (email magic links) |
| Email | Resend (login links) |
| Validation | Zod 4 |
| Charts | Recharts 3 |
| Styling | Tailwind CSS 4 |
| Tests | Vitest 4 |
| Worker runtime | `tsx` (runs `backend/worker/dm-worker.ts`) |
| Instagram | Official Meta Graph API (Instagram Login) |

## Runtime — two processes, two datastores

- **Web app + API** (`npm run dev` / `npm start`): Next.js. Serves the dashboard,
  the OAuth callback, and the incoming webhook. Serverless-friendly; runs on Vercel.
- **Worker** (`npm run worker`): a long-running Node process. Consumes the send
  queue, sends the DMs, runs the polling reconciler, and performs the follow-gate
  `is_user_follow_business` checks. **Must stay always-on**, so it cannot run on
  Vercel — it needs an always-on host.
- **PostgreSQL**: campaigns, DM logs, accounts, sessions, tracked links, click events.
- **Redis**: the BullMQ send queue and the per-account rate limiter. Must speak the
  native Redis protocol over TCP (an HTTP-only Redis will not work with BullMQ).

The web app and worker use the same Postgres database, Redis instance, and
`ENCRYPTION_KEY`. Vercel uses the database's external URL; the Render worker can
use its private URL. Both use the same authenticated TCP Redis URL because
BullMQ does not support HTTP-only Redis APIs. The web app stores encrypted
Instagram tokens; the worker decrypts them to send replies.

## Recommended deployment layout

The deployment prepared in this repository:

| Piece | Service | Notes |
| --- | --- | --- |
| Web app and webhook | Vercel | Set the project root to `frontend/`. |
| Background worker | Render | Must use an always-on worker plan. |
| PostgreSQL | Render | The Blueprint uses a paid plan; Vercel needs the external URL. |
| Redis | Redis Cloud or another authenticated TCP Redis provider | Share its TLS URL with Vercel and Render. |
| Login email | Resend | Required unless SMTP is configured. |
| Instagram API | Meta app with Instagram Login | App Review may be needed for accounts without a role on your app. |

## Environment variables

Names only — values live in `.env` (gitignored) or the host's env settings, never
in the repo. Full descriptions are in [setup.md](setup.md#environment-variables).

`NEXTAUTH_URL`, `NEXTAUTH_SECRET`, `CRON_SECRET`, `ENCRYPTION_KEY`, `DATABASE_URL`,
`REDIS_URL`, `RESEND_API_KEY`, `EMAIL_FROM`, `META_GRAPH_API_VERSION`,
`INSTAGRAM_APP_ID`, `INSTAGRAM_APP_SECRET`, `FACEBOOK_APP_SECRET`,
`WEBHOOK_VERIFY_TOKEN`.
