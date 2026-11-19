import "dotenv/config";
import { app } from "./app";

const rawPort = process.env.PORT ?? "3000";
const port = Number(rawPort);
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error(`Invalid PORT: ${JSON.stringify(rawPort)}`);
}

app.listen(port, () => {
  console.log(`backend listening on :${port}`);
});
