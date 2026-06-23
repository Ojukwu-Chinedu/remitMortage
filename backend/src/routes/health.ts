import { Router } from "express";

export const healthRouter = Router();

/**
 * @openapi
 * /api/health:
 *   get:
 *     summary: Check API health
 *     description: Returns the current service status and server timestamp.
 *     tags:
 *       - Health
 *     responses:
 *       200:
 *         description: API service is reachable.
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/HealthResponse'
 */
healthRouter.get("/", (_req, res) => {
  res.json({
    status: "ok",
    service: "remitmortgage-api",
    timestamp: new Date().toISOString(),
  });
});
