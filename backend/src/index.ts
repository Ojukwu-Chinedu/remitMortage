import "dotenv/config";
import express from "express";
import cors from "cors";
import swaggerUi from "swagger-ui-express";
import { healthRouter } from "./routes/health.js";
import { verificationRouter } from "./routes/verification.js";
import { borrowerRouter } from "./routes/borrower.js";
import { swaggerSpec } from "./docs/swagger.js";

const app = express();
const PORT = process.env.PORT || 4000;

// ── Middleware ───────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());

// ── Routes ──────────────────────────────────────────────────────────────
app.use("/api/health", healthRouter);
app.use("/api/verification", verificationRouter);
app.use("/api/borrower", borrowerRouter);
app.use("/api/docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// ── Start Server ────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`🚀 RemitMortgage API running on http://localhost:${PORT}`);
});

export default app;
