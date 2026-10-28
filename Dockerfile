# OpenReply — self-hosted Docker image
#
# Two runtime processes ship from this image:
#   - web:    `npm run start`  → next start (needs .next + node_modules)
#   - worker: `npm run worker` → tsx backend/worker/bootstrap.ts (runs RAW TypeScript,
#             not a bundled output — needs the generated Prisma client, the
#             full source tree under frontend/lib/ and backend/worker/, and
#             workspace tsconfig.json files for the `@/*` path alias)
#   - cron:   `sh scripts/cron.sh` → the scheduler for /api/cron, which nothing
#             runs off Vercel (see docs/deploy-dokploy.md). It needs scripts/
#             in the image and wget on PATH; node:20-slim ships neither.
#
# next.config.ts does not set `output: "standalone"`, so `next start` already
# requires the full node_modules tree at runtime — there is no slimmer
# standalone bundle to fall back to here. Given that, this Dockerfile does
# NOT try to strip node_modules/tsconfig.json/source files out of the final
# stage: doing so is exactly what breaks the worker (MODULE_NOT_FOUND on
# `@/lib/...` imports, because tsx has no tsconfig to resolve the alias
# against, and no frontend/app/generated/prisma to import from).

FROM node:20-slim AS build
WORKDIR /app

COPY package.json package-lock.json ./
COPY frontend/package.json ./frontend/package.json
COPY backend/package.json ./backend/package.json
RUN npm ci

COPY . .
# `npm run build` = `prisma generate && next build` (see package.json) —
# generates frontend/app/generated/prisma AND compiles frontend/.next/.
RUN npm run build

FROM node:20-slim AS runner
WORKDIR /app
ENV NODE_ENV=production

# scripts/cron.sh calls the /api/cron routes with wget, which node:20-slim does
# not include.
RUN apt-get update \
 && apt-get install -y --no-install-recommends wget ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/frontend/.next ./frontend/.next
COPY --from=build /app/frontend/app/generated ./frontend/app/generated
COPY --from=build /app/frontend/app ./frontend/app
COPY --from=build /app/frontend/components ./frontend/components
COPY --from=build /app/frontend/public ./frontend/public
COPY --from=build /app/frontend/lib ./frontend/lib
COPY --from=build /app/backend/worker ./backend/worker
COPY --from=build /app/backend/package.json ./backend/package.json
COPY --from=build /app/backend/tsconfig.json ./backend/tsconfig.json
COPY --from=build /app/frontend/package.json ./frontend/package.json
COPY --from=build /app/frontend/tsconfig.json ./frontend/tsconfig.json
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/scripts ./scripts
COPY --from=build /app/prisma.config.ts ./prisma.config.ts
COPY --from=build /app/frontend/next.config.ts ./frontend/next.config.ts
COPY --from=build /app/frontend/postcss.config.mjs ./frontend/postcss.config.mjs
COPY --from=build /app/frontend/eslint.config.mjs ./frontend/eslint.config.mjs
COPY --from=build /app/tsconfig.json ./tsconfig.json
COPY --from=build /app/package.json ./package.json

EXPOSE 3000
# Default to the web process — the worker service overrides this with
# `command: ["npm", "run", "worker"]` in whatever compose/stack file deploys
# it (see openreply-vps.stack.yml in EvolutionAPI/omni-nexus for an example).
CMD ["npm", "run", "start"]
