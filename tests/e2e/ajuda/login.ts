import { expect, type Page } from "@playwright/test";
import { SENHA } from "./email";

/** Entra pela tela de login com email/senha (contas do seed usam SENHA). */
export async function entrarCom(page: Page, email: string, senha = SENHA, esperarSucesso = true) {
  await page.goto("/entrar");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Senha").fill(senha);
  await page.getByRole("button", { name: "Entrar" }).click();
  // Espera sair da tela de login (a ação é assíncrona); nos testes de falha, não espera.
  if (esperarSucesso) await page.waitForURL((url) => !url.pathname.startsWith("/entrar"));
}

export async function sairDoApp(page: Page) {
  await page.goto("/conta");
  await page.getByRole("button", { name: "Sair" }).click();
  await expect(page).toHaveURL(/\/entrar/);
}
