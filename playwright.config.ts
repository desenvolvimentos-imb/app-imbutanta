import { defineConfig, devices } from "@playwright/test";

// Testes ponta a ponta em tela de celular (mobile-first, constituição princípio I).
// Exigem o Supabase local rodando (`npx supabase start`) e o app em http://localhost:3000.
export default defineConfig({
  testDir: "tests/e2e",
  fullyParallel: false, // os testes compartilham o mesmo banco local
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? "github" : "list",
  use: {
    baseURL: "http://localhost:3000",
    trace: "on-first-retry",
  },
  projects: [{ name: "celular", use: { ...devices["Pixel 7"] } }],
  webServer: {
    command: "npm run dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
