import { createServer } from "node:http";
import { loadEnvConfig } from "@next/env";
import path from "node:path";

// Render's free tier only offers Web Services. This tiny HTTP listener lets
// the queue worker run as one while keeping its actual work in dm-worker.ts.
// Locally, the same entry point can still load the repository-root .env file.
const projectRoot = path.basename(process.cwd()) === "backend"
  ? path.resolve(process.cwd(), "..")
  : process.cwd();
loadEnvConfig(projectRoot);

const port = Number(process.env.PORT ?? 10000);
const server = createServer((request, response) => {
  if ((request.method === "GET" || request.method === "HEAD") && request.url === "/health") {
    response.writeHead(200, { "content-type": "application/json; charset=utf-8" });
    response.end(request.method === "HEAD" ? undefined : JSON.stringify({ status: "ok" }));
    return;
  }

  response.writeHead(404, { "content-type": "application/json; charset=utf-8" });
  response.end(JSON.stringify({ error: "Not found" }));
});

server.listen(port, "0.0.0.0", () => {
  console.log(`[Worker health] Listening on 0.0.0.0:${port}`);
  void import("./dm-worker").catch((error: unknown) => {
    console.error("[DM Worker] Failed to start:", error);
    server.close(() => process.exit(1));
  });
});
