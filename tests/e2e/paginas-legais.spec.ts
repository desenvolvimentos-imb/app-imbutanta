// Páginas públicas de Política de Privacidade e Termos de Uso (exigidas pelo Google para o
// login e importantes para a LGPD). Devem abrir SEM login, mesmo com a regra de que todas as
// outras páginas exigem login (RF-024).
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { entrarCom } from "./ajuda/login";

test("privacidade e termos abrem sem login", async ({ page }) => {
  await page.goto("/privacidade");
  await expect(page).toHaveURL(/\/privacidade$/);
  await expect(page.getByRole("heading", { level: 1, name: "Política de Privacidade" })).toBeVisible();
  await expect(page.getByText(/exclu/i).first()).toBeVisible();

  await page.goto("/termos");
  await expect(page).toHaveURL(/\/termos$/);
  await expect(page.getByRole("heading", { level: 1, name: "Termos de Uso" })).toBeVisible();
});

test("a política diz quais dados são guardados e como excluir a conta", async ({ page }) => {
  await page.goto("/privacidade");
  await expect(page.getByText(/nome e o email/i).first()).toBeVisible();
  await expect(page.getByText(/Excluir minha conta/).first()).toBeVisible();
});

test("a tela de entrar e a de cadastro levam às duas páginas", async ({ page }) => {
  for (const rota of ["/entrar", "/cadastrar"]) {
    await page.goto(rota);
    await expect(page.getByRole("link", { name: "Política de Privacidade" }).first()).toHaveAttribute("href", "/privacidade");
    await expect(page.getByRole("link", { name: "Termos de Uso" }).first()).toHaveAttribute("href", "/termos");
  }
});

test("quem está logado também lê as páginas, sem ser redirecionado", async ({ page }) => {
  await entrarCom(page, "membro@teste.local");
  await page.goto("/privacidade");
  await expect(page).toHaveURL(/\/privacidade$/);
});

test("as páginas atendem ao WCAG AA", async ({ page }) => {
  for (const rota of ["/privacidade", "/termos"]) {
    await page.goto(rota);
    const r = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]).analyze();
    expect(r.violations.map((v) => `${v.id}: ${v.help}`), rota).toEqual([]);
  }
});
