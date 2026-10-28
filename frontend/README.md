# Frontend and webhook app

This is the Next.js application deployed to Vercel. Its App Router serves the
dashboard, OAuth callbacks, API endpoints, and Meta webhooks. Instagram and
database logic shared with the background worker lives in `lib/`.

Vercel's project root directory is `frontend`. The npm workspace and Prisma
schema remain at the repository root; `vercel-build` generates Prisma, applies
database migrations, and builds this Next.js app.
