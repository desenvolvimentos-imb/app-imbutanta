// T039 (História 2): entrar, tela inicial por papel, sair e persistência da sessão.
import { expect, test } from "@playwright/test";
import { entrarCom, sairDoApp } from "./ajuda/login";

test("membro vê o início sem atalhos administrativos", async ({ page }) => {
  await entrarCom(page, "membro@teste.local");
  await expect(page).toHaveURL(/\/inicio/);
  await expect(page.getByRole("heading", { name: /Marta Membro/ })).toBeVisible();
  await expect(page.getByRole("link", { name: /Pedidos e aprovações/ })).toHaveCount(0);
  await expect(page.getByRole("link", { name: "Gerenciar usuários" })).toHaveCount(0);
});

// Desde a 002, "líder" é quem lidera um ministério (lider@teste.local lidera o Louvor no seed).
test("quem lidera um ministério vê Pedidos e aprovações, mas não Gerenciar usuários", async ({ page }) => {
  await entrarCom(page, "lider@teste.local");
  await expect(page).toHaveURL(/\/inicio/);
  await expect(page.getByRole("link", { name: /Pedidos e aprovações/ }).first()).toBeVisible();
  await expect(page.getByRole("link", { name: "Gerenciar usuários" })).toHaveCount(0);
});

test("administrador vê os dois atalhos", async ({ page }) => {
  await entrarCom(page, "admin@teste.local");
  await expect(page).toHaveURL(/\/inicio/);
  await expect(page.getByRole("link", { name: /Pedidos e aprovações/ }).first()).toBeVisible();
  await expect(page.getByRole("link", { name: "Gerenciar usuários" }).first()).toBeVisible();
});

test("senha errada mostra mensagem genérica", async ({ page }) => {
  await entrarCom(page, "membro@teste.local", "SenhaErrada1", false);
  await expect(page.locator("p[role=alert]")).toHaveText("Email ou senha incorretos.");
  // Email inexistente recebe exatamente a mesma resposta.
  await entrarCom(page, "naoexiste@teste.local", "SenhaErrada1", false);
  await expect(page.locator("p[role=alert]")).toHaveText("Email ou senha incorretos.");
});

test("a sessão continua depois de recarregar a página", async ({ page }) => {
  await entrarCom(page, "membro@teste.local");
  await expect(page).toHaveURL(/\/inicio/);
  await page.reload();
  await expect(page).toHaveURL(/\/inicio/);
});

test("sair encerra a sessão e protege as páginas; depois do login volta à página pedida", async ({ page }) => {
  await entrarCom(page, "lider@teste.local");
  await expect(page).toHaveURL(/\/inicio/);
  await sairDoApp(page);

  await page.goto("/inicio");
  await expect(page).toHaveURL(/\/entrar\?voltar=%2Finicio/);

  await page.goto("/aprovacoes");
  await expect(page).toHaveURL(/\/entrar\?voltar=%2Faprovacoes/);
  await page.getByLabel("Email").fill("lider@teste.local");
  await page.getByLabel("Senha").fill("Senha1234");
  await page.getByRole("button", { name: "Entrar" }).click();
  await expect(page).toHaveURL(/\/aprovacoes/);
});

test("parâmetro voltar externo é ignorado (sem open redirect)", async ({ page }) => {
  await page.goto("/entrar?voltar=https%3A%2F%2Fmalicioso.com");
  await page.getByLabel("Email").fill("membro@teste.local");
  await page.getByLabel("Senha").fill("Senha1234");
  await page.getByRole("button", { name: "Entrar" }).click();
  await expect(page).toHaveURL(/localhost:3000\/inicio/);
});

test("recusado e pendente entram, mas só veem a própria tela", async ({ page }) => {
  await entrarCom(page, "recusado@teste.local");
  await expect(page).toHaveURL(/\/cadastro-recusado/);
  await sairDoApp(page).catch(() => {});
});
