const path = require("node:path");
const { loadEnvConfig } = require("@next/env");

// The Next.js workspace lives in frontend/, while local secrets stay in the
// repository-root .env file shared with the background worker.
loadEnvConfig(path.resolve(process.cwd(), ".."));
require("next/dist/bin/next");
