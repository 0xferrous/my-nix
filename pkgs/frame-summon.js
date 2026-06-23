const ws = new WebSocket("ws://127.0.0.1:1248/?identity=frame-extension", {
  headers: {
    Origin: "chrome-extension://ldcoohedfbjoobcadoglnnmmfbdlmmhf",
  },
});

const timeout = setTimeout(() => {
  ws.close();
  console.error("Connection timeout");
  process.exit(1);
}, 50000);

ws.addEventListener("open", () => {
  console.log("Connected");
  ws.send(
    JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "frame_summon",
      params: [],
    }),
  );
});

ws.addEventListener("message", (event) => {
  console.log("Received:", event.data.toString());
  clearTimeout(timeout);
  const response = JSON.parse(event.data.toString());
  ws.close();

  if (response.error) {
    console.error(response.error.message || "RPC error");
    process.exit(1);
  }
});

ws.addEventListener("error", (event) => {
  clearTimeout(timeout);
  console.error(event.message || "WebSocket error");
  process.exit(1);
});

ws.addEventListener("close", () => {
  clearTimeout(timeout);
});
