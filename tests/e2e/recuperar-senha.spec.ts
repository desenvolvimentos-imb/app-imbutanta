// T051 (História 4): recuperar e redefinir a senha.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, esperarEmail, extrairLink, SENHA } from "./ajuda/email";
import { entrarCom } from "./ajuda/login";

const NOVA_SENHA = "NovaSenha5678";

async function pedirRecuperacao(page: import("@playwright/test").Page, email: string) {
  await page.goto("/recuperar-senha");
  await page.getByLabel("Email").fill(email);
  await page.getByRole("button", { name: "Enviar link" }).click();
}

test("email existente e inexistente recebem exatamente a mesma resposta", async ({ page }) => {
  await pedirRecuperacao(page, "membro@teste.local");
  const resposta1 = await page.locator("p[role=status]").innerText();

  await pedirRecuperacao(page, "ninguem.assim@teste.local");
  const resposta2 = await page.locator("p[role=status]").innerText();

  expect(resposta1).toBe(resposta2);
  expect(resposta1).toMatch(/Se o email estiver cadastrado/);
});

test("redefinir a senha pelo link: nova funciona, antiga não, link não vale duas vezes", async ({ page }) => {
  // Conta própria, para não alterar a senha das contas do seed.
  const email = emailNovo("recupera");
  const admin = clienteAdmin();
  const { error } = await admin.auth.admin.createUser({
    email,
    password: SENHA,
    email_confirm: true,
    user_metadata: { nome: "Pessoa Recupera" },
  });
  if (error) throw error;

  await pedirRecuperacao(page, email);
  await expect(page.locator("p[role=status]")).toBeVisible();
  const link = extrairLink(await esperarEmail(email), "/auth/confirmar");

  await page.goto(link);
  await expect(page).toHaveURL(/\/redefinir-senha/);

  // Senha fraca é recusada com explicação.
  await page.getByLabel("Nova senha", { exact: true }).fill("abc");
  await page.getByLabel("Repita a nova senha").fill("abc");
  await page.getByRole("button", { name: "Salvar nova senha" }).click();
  await expect(page.getByText("A senha precisa ter pelo menos 8 caracteres.")).toBeVisible();

  // Senhas diferentes também.
  await page.getByLabel("Nova senha", { exact: true }).fill(NOVA_SENHA);
  await page.getByLabel("Repita a nova senha").fill(NOVA_SENHA + "x");
  await page.getByRole("button", { name: "Salvar nova senha" }).click();
  await expect(page.getByText("As senhas não são iguais.")).toBeVisible();

  await page.getByLabel("Nova senha", { exact: true }).fill(NOVA_SENHA);
  await page.getByLabel("Repita a nova senha").fill(NOVA_SENHA);
  await page.getByRole("button", { name: "Salvar nova senha" }).click();
  await expect(page).toHaveURL(/\/entrar/);
  await expect(page.getByText(/senha foi alterada/i)).toBeVisible();

  // A antiga não funciona mais; a nova sim.
  await entrarCom(page, email, SENHA, false);
  await expect(page.locator("p[role=alert]")).toHaveText("Email ou senha incorretos.");
  await entrarCom(page, email, NOVA_SENHA);
  await expect(page).toHaveURL(/\/(aguardando-aprovacao|inicio)/);

  // Reabrir o mesmo link: expirado/já usado.
  await page.context().clearCookies();
  await page.goto(link);
  await expect(page).toHaveURL(/\/recuperar-senha\?erro=link/);
  await expect(page.getByText(/expirou ou já foi usado/i)).toBeVisible();
});
