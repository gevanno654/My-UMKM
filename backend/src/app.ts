import express from "express";
import { authRouter, meRouter } from "./auth/routes";
import { productsRouter } from "./products/routes";
import { restocksRouter } from "./restocks/routes";
import { salesRouter } from "./sales/routes";

export const app = express();

app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.use("/api/v1/auth", authRouter);
app.use("/api/v1", meRouter);
app.use("/api/v1/products", productsRouter);
app.use("/api/v1/sales", salesRouter);
app.use("/api/v1/restocks", restocksRouter);
