import { loadEnvConfig } from "@next/env";
import path from "node:path";

// Local development keeps one root .env for both workspaces. In production,
// Render injects variables into the process and no .env file is required.
const projectRoot = path.basename(process.cwd()) === "backend"
  ? path.resolve(process.cwd(), "..")
  : process.cwd();
loadEnvConfig(projectRoot);

void import("./dm-worker").catch((error: unknown) => {
  console.error("[DM Worker] Failed to start:", error);
  process.exitCode = 1;
});
