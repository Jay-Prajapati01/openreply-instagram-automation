# Backend worker

This workspace runs OpenReply's persistent BullMQ consumer and comment polling
reconciler. It shares the domain, database, and Meta API code in `frontend/lib`
with the Next.js app, and uses the Prisma schema and migrations in `../prisma`.

Run it from the repository root with `npm run worker`. Local development reads
the root `.env`; Render supplies environment variables directly and starts the
worker without requiring an `.env` file.
