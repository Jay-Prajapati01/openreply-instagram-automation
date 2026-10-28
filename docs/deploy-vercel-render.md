# Personal free-tier deployment

This repository is an npm workspace monorepo:

- `frontend/` is the Next.js dashboard, API, OAuth callback, and Meta webhook.
- `backend/` contains the BullMQ worker.
- `prisma/` contains the shared database schema and migrations.

This guide describes a zero-cost personal-use attempt using Vercel Hobby,
external Neon Postgres, TCP Redis, and a Render Free Web Service for the worker.
It is a hobby setup, not an uptime guarantee. Render has no free background
worker plan, so this repository runs the worker inside a Web Service with a
small HTTP health endpoint. A free uptime monitor can ping that endpoint every
five minutes to reduce idle spin-downs. This consumes nearly all of Render's
750 monthly free instance hours, shared by every free service in the workspace;
other services can exhaust the allowance. Render may also restart or suspend
free services.

Vercel Hobby is restricted to personal, non-commercial use. Do not use it for a
monetized or business deployment unless your plan permits that use.

## 1. Create the external data services

1. Create a Neon PostgreSQL project and copy both connection strings. Set the
   pooled URL (hostname includes `-pooler`) as `DATABASE_URL` for app traffic;
   use the direct, non-pooler URL as `DIRECT_URL` for Prisma migrations. Keep
   the credentials private.
2. Create one Redis database with native TCP and TLS access, such as Redis
   Cloud or Upstash Redis. Copy its `rediss://` connection string. Do not use a
   REST-only Redis endpoint: BullMQ requires native Redis TCP commands.
3. Use these same `DATABASE_URL` and `REDIS_URL` values in Vercel and Render.
4. Generate one 32-byte hex `ENCRYPTION_KEY` (`openssl rand -hex 32`) and use
   the same value in both services.

Database free-plan quotas, sleep/pause behavior, and retention are controlled by
the database provider. Keep a backup of any data you care about.

## 2. Deploy the frontend to Vercel

Connect this GitHub repository to Vercel. Set **Root Directory** to `frontend`,
framework to Next.js, and build command to `npm run vercel-build`. The build
generates Prisma, applies pending migrations, then builds the frontend. The
database must be reachable during the build.

Set these Vercel Production environment variables:

- `NEXTAUTH_URL`: the assigned Vercel URL, such as `https://your-app.vercel.app`.
- `NEXTAUTH_SECRET`: a random secret (`openssl rand -base64 32`).
- `CRON_SECRET`: a separate random secret.
- `DATABASE_URL`, `DIRECT_URL`, `REDIS_URL`, and `ENCRYPTION_KEY` from Step 1.
- `EMAIL_SERVER`: Gmail SMTP URL (see `setup.md` for app-password setup).
- `EMAIL_FROM`: the Gmail address used to send sign-in links.
- `ALLOWED_EMAILS`: your email address; this restricts login to you.
- `META_GRAPH_API_VERSION`, `INSTAGRAM_APP_ID`, `INSTAGRAM_APP_SECRET`,
  `FACEBOOK_APP_SECRET`, and `WEBHOOK_VERIFY_TOKEN` from your Meta app setup.

You do not need Resend or a purchased custom domain for this personal setup.

## 3. Deploy the worker to Render Free

Create a Blueprint from this repository and apply the root `render.yaml`. The
Blueprint creates a Free Web Service named `openreply-worker`; it does not create
a Render database. Set its environment values when prompted:

- `DATABASE_URL`, `REDIS_URL`, `ENCRYPTION_KEY` (same values as Vercel).
- `NEXTAUTH_URL` (the Vercel URL) and `NEXTAUTH_SECRET` (same value as Vercel).
- The Meta variables listed above.

The worker listens on Render's `PORT` and returns `200` at `/health`. After
deploying, create a free HTTP(S) monitor in UptimeRobot for
`https://YOUR-RENDER-SERVICE.onrender.com/health`, using its five-minute
interval. This is only a best-effort workaround for Render's 15-minute idle
spin-down; it does not make the service guaranteed always-on. Watch Render's
workspace free-hour usage, especially because all free services share the
allowance.

## 4. Run migrations and connect Meta

The Vercel build runs `prisma migrate deploy` using `DIRECT_URL`, falling back
to `DATABASE_URL` if no direct URL is configured. If you need to initialize the
database separately, configure a local `.env` with the Neon URLs and run
`npm run db:migrate` once from the repo root.

After Vercel is live, register these URLs in your Meta app:

- Instagram OAuth redirect: `https://YOUR-VERCEL-DOMAIN/api/instagram/callback`
- Meta webhook callback: `https://YOUR-VERCEL-DOMAIN/api/webhook`
- Subscribe to the `comments` and `messages` fields you use.

The webhook still needs Meta's callback verification handshake and verify
token. No custom-domain purchase or separate domain-provider verification is
needed for the Vercel URL. For Development-mode testing, add your Instagram
professional account to the app with the required tester access and accept the
invitation.

Finally, open `https://YOUR-VERCEL-DOMAIN/api/health`. It should report healthy
Postgres, Redis, and worker heartbeat checks. Sign in, connect Instagram, and
test a campaign with a comment from another account before relying on it.
