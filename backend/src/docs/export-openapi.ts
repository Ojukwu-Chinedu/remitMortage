import { writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { swaggerSpec } from "./swagger.js";

const outputPath = resolve(process.cwd(), "openapi.json");

async function main() {
  await writeFile(outputPath, `${JSON.stringify(swaggerSpec, null, 2)}\n`, "utf8");

  console.log(`OpenAPI spec written to ${outputPath}`);
}

main().catch((error) => {
  console.error("Failed to export OpenAPI spec:", error);
  process.exitCode = 1;
});
