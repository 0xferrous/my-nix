import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type RadarStatus = "running" | "done" | "idle";

function assistantSummary(ctx: ExtensionContext): string {
  const entries = ctx.sessionManager.getBranch();
  for (let index = entries.length - 1; index >= 0; index--) {
    const entry = entries[index];
    if (entry.type !== "message" || entry.message.role !== "assistant") continue;

    const text = entry.message.content
      .filter((part): part is { type: "text"; text: string } => part.type === "text")
      .map((part) => part.text)
      .join(" ")
      .replace(/\s+/g, " ")
      .trim();
    if (text) return text.slice(0, 120);
  }
  return "ready for input";
}

export default function (pi: ExtensionAPI) {
  let task: string | undefined;
  let sends = Promise.resolve();

  function notify(status: RadarStatus, msg?: string, nextTask?: string): Promise<void> {
    if (!process.env.ZELLIJ || !process.env.ZELLIJ_PANE_ID) return Promise.resolve();

    const args = [
      "notify",
      "generic",
      "--status",
      status,
      "--source",
      "pi",
    ];
    if (msg) args.push("--msg", msg);
    if (nextTask) args.push("--task", nextTask);

    sends = sends
      .then(async () => {
        await pi.exec("zj-radar", args, { timeout: 7000 });
      })
      .catch(() => {});
    return sends;
  }

  pi.on("before_agent_start", async (event) => {
    task = event.prompt.replace(/\s+/g, " ").trim().slice(0, 120) || undefined;
  });

  pi.on("agent_start", async () => {
    await notify("running", "working", task);
  });

  pi.on("tool_execution_start", async (event) => {
    await notify("running", `using ${event.toolName}`, task);
  });

  pi.on("agent_settled", async (_event, ctx) => {
    await notify("done", assistantSummary(ctx));
  });

  pi.on("session_shutdown", async () => {
    await notify("idle");
  });
}
