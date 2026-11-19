import { defineConfig } from "vitest/config";
import path from "node:path";

// Testes unitários rodam em Node puro, sem navegador e sem internet.
export default defineConfig({
  test: {
    include: ["tests/unit/**/*.test.ts"],
    environment: "node",
  },
  resolve: {
    alias: { "@": path.resolve(__dirname, "src") },
  },
});
