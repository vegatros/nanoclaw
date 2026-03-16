import { createServer } from "http";
import { spawn } from "child_process";

const PORT = parseInt(process.env.PORT || "3000");

const server = createServer((req, res) => {
  if (req.method === "GET" && req.url === "/") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok" }));
    return;
  }

  if (req.method === "POST" && req.url === "/run") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      const child = spawn("/app/entrypoint.sh", [], {
        stdio: ["pipe", "pipe", "pipe"],
        cwd: "/workspace/group",
      });

      child.stdin.write(body);
      child.stdin.end();

      let stdout = "";
      let stderr = "";
      child.stdout.on("data", (d) => (stdout += d));
      child.stderr.on("data", (d) => (stderr += d));

      child.on("close", (code) => {
        const outputMatch = stdout.match(
          /---NANOCLAW_OUTPUT_START---([\s\S]*?)---NANOCLAW_OUTPUT_END---/
        );
        const output = outputMatch ? outputMatch[1].trim() : stdout;

        res.writeHead(code === 0 ? 200 : 500, {
          "Content-Type": "application/json",
        });
        res.end(
          JSON.stringify({
            exitCode: code,
            output: tryParseJson(output),
            stderr: stderr || undefined,
          })
        );
      });
    });
    return;
  }

  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "Not found" }));
});

function tryParseJson(s) {
  try {
    return JSON.parse(s);
  } catch {
    return s;
  }
}

server.listen(PORT, () => console.log(`Listening on :${PORT}`));
