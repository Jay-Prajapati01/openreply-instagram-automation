# Deploy OpenReply to Vercel and Render

This repository is an npm workspace monorepo:

- `frontend/` is the Next.js dashboard, API, OAuth callback, and Meta webhook.
- `backend/` contains the always-on BullMQ worker.
- `prisma/` contains the shared database schema and migrations.

## Before deploying

1. Push this repository to a GitHub repository you control. Keep `.env` and all credentials out of Git; `.gitignore` excludes them.
2. Have a Meta developer app, an Instagram Business or Creator account, and a Resend account ready. Meta callback and webhook setup is in [setup.md](setup.md#the-meta-app).
3. Choose a Vercel plan that fits your use. Vercel Hobby is for non-commercial personal use, and its cron jobs run at most once a day.
4. Plan for paid Render resources for the persistent worker and production Postgres. A TCP Redis service with TLS and a password is also required. Render Key Value is private-network oriented, while the Vercel app needs a public authenticated Redis endpoint.

## Render: worker and Postgres

The root `render.yaml` is a Render Blueprint. Open the Render Dashboard, create a Blueprint from this GitHub repository, review its worker and Postgres plans, then apply it. Applying provisions paid compute and database resources.

The Blueprint configures:

- A Render background worker using `npm run worker --workspace=backend`.
- A Render Postgres database, with a private URL for the worker.
- Secret prompts for `REDIS_URL`, `ENCRYPTION_KEY`, the Meta app credentials, and `NEXTAUTH_URL`.

For `REDIS_URL`, use the TLS connection URL from an authenticated TCP Redis provider. Use the same Redis instance for both Vercel and Render. The app requires native Redis TCP commands for BullMQ; Redis REST endpoints will not work.

Set `ENCRYPTION_KEY` to the same 64-character hex value in Vercel and Render. Set `NEXTAUTH_URL` to the eventual Vercel production domain. You can update it in Render after Vercel assigns the domain.

## Vercel: frontend and webhook

Create a Vercel project from this repository and set **Root Directory** to `frontend`. Keep the framework as Next.js and set the build command to `npm run vercel-build`. This command generates Prisma, applies pending migrations to the production database, and builds the frontend.

Set these production environment variables in Vercel:

- `NEXTAUTH_URL`: the Vercel production URL, such as `https://openreply-example.vercel.app`.
- `NEXTAUTH_SECRET`, `CRON_SECRET`, `ENCRYPTION_KEY`.
- `DATABASE_URL`: the Render Postgres **external** connection URL. Do not use its private hostname from Vercel.
- `REDIS_URL`: the same authenticated TLS Redis URL configured on the Render worker.
- `RESEND_API_KEY`, `EMAIL_FROM` (or `EMAIL_SERVER`).
- `META_GRAPH_API_VERSION`, `INSTAGRAM_APP_ID`, `INSTAGRAM_APP_SECRET`, `FACEBOOK_APP_SECRET`, `WEBHOOK_VERIFY_TOKEN`.
- Optionally `ALLOWED_EMAILS`, set to your email address to keep sign-in limited to you.

Set `NEXTAUTH_URL`, `ENCRYPTION_KEY`, and `REDIS_URL` on Render as well. The Render worker gets its private Postgres URL from the Blueprint. The Meta app secrets are provided to the worker by the Blueprint prompts.

After adding the Vercel environment variables, redeploy the production branch. Confirm `/api/health` reports database, Redis, and worker health before enabling campaigns.

## Connect the Meta app

Once the Vercel production domain is live, follow [setup.md](setup.md#the-meta-app) to register:

- OAuth redirect: `https://YOUR-DOMAIN/api/instagram/callback`
- Webhook callback: `https://YOUR-DOMAIN/api/webhook`
- Webhook fields: `comments` and `messages`

Set the app's privacy policy, terms, and data-deletion URLs to the matching pages on your Vercel domain. App Review and Advanced Access may be required when connecting accounts that do not have a role on your Meta app.

## Verify

1. Open `https://YOUR-DOMAIN/api/health`; check that Postgres, Redis, and the worker heartbeat are healthy.
2. Complete Instagram login from the dashboard and confirm the account is connected.
3. Create a campaign for one existing post and test with a different Instagram account. OpenReply ignores comments made by the connected account itself.
4. Review DM Logs and Render worker logs if a test comment does not receive a reply.
