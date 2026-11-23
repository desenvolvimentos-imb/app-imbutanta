import { defineConfig } from "vitest/config";
import path from "node:path";

// Testes de integração: falam com o Supabase LOCAL de verdade (`npx supabase start`), com duas
// sessões de usuários ao mesmo tempo. Ficam separados dos unitários (que rodam sem banco).
export default defineConfig({
  test: {
    include: ["tests/integration/**/*.test.ts"],
    environment: "node",
    testTimeout: 120_000,
    hookTimeout: 120_000,
  },
  resolve: {
    alias: { "@": path.resolve(__dirname, "src") },
  },
});
