import express from "express";
import { authRouter, meRouter } from "./auth/routes";

export const app = express();

app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.use("/api/v1/auth", authRouter);
app.use("/api/v1", meRouter);
