// T030 (História 1): cadastro com email/senha e tela de aguardando aprovação.
import { expect, test } from "@playwright/test";
import { emailNovo, esperarEmail, extrairLink, SENHA } from "./ajuda/email";

test("cadastro com email e senha: confirma o email e cai na tela de espera", async ({ page }) => {
  const email = emailNovo("cadastro");

  await page.goto("/cadastrar");
  await page.getByLabel("Nome").fill("Pessoa Nova");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Senha").fill(SENHA);
  await page.getByRole("button", { name: "Criar conta" }).click();

  await expect(page.getByText(/enviamos um link/i)).toBeVisible();

  const html = await esperarEmail(email);
  await page.goto(extrairLink(html, "/auth/confirmar"));

  await expect(page).toHaveURL(/\/aguardando-aprovacao/);
  await expect(page.getByRole("heading", { name: /aguardando aprovação/i })).toBeVisible();
});

test("pendente não acessa conteúdo nem telas administrativas pelo endereço direto", async ({ page }) => {
  const email = emailNovo("pendente");
  await page.goto("/cadastrar");
  await page.getByLabel("Nome").fill("Pessoa Pendente");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Senha").fill(SENHA);
  await page.getByRole("button", { name: "Criar conta" }).click();
  await page.goto(extrairLink(await esperarEmail(email), "/auth/confirmar"));
  await expect(page).toHaveURL(/\/aguardando-aprovacao/);

  for (const rota of ["/inicio", "/aprovacoes", "/usuarios", "/conta"]) {
    await page.goto(rota);
    await expect(page).toHaveURL(/\/aguardando-aprovacao/);
  }
});

test("senha fraca e nome vazio mostram o que corrigir, em português", async ({ page }) => {
  await page.goto("/cadastrar");
  await page.getByLabel("Nome").fill("   ");
  await page.getByLabel("Email").fill(emailNovo("fraca"));
  await page.getByLabel("Senha").fill("abc");
  await page.getByRole("button", { name: "Criar conta" }).click();

  await expect(page.getByText(/informe o seu nome/i)).toBeVisible();
  await expect(page.getByText("A senha precisa ter pelo menos 8 caracteres.")).toBeVisible();
});

test("email já cadastrado não revela que a conta existe", async ({ page }) => {
  await page.goto("/cadastrar");
  await page.getByLabel("Nome").fill("Alguém");
  await page.getByLabel("Email").fill("membro@teste.local"); // existe no seed
  await page.getByLabel("Senha").fill(SENHA);
  await page.getByRole("button", { name: "Criar conta" }).click();

  // A resposta é igual à de um cadastro novo: nada de "este email já está cadastrado".
  await expect(page.getByText(/enviamos um link/i)).toBeVisible();
  await expect(page.getByText(/já (existe|está cadastrado)/i)).toHaveCount(0);
});

test("sem login, páginas protegidas levam ao login", async ({ page }) => {
  await page.goto("/inicio");
  await expect(page).toHaveURL(/\/entrar\?voltar=%2Finicio/);
});
