// T046 (História 3 da 001): o administrador aprova e recusa cadastros pendentes. Desde a 002, o
// líder de ministério decide PEDIDOS de entrada: ver tests/e2e/aprovacao-por-lider.spec.ts.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, SENHA } from "./ajuda/email";
import { entrarCom, sairDoApp } from "./ajuda/login";

// Cria uma pessoa pendente já com email confirmado (aparece na fila).
async function criarPendente(nome: string) {
  const email = emailNovo("fila");
  const { error } = await clienteAdmin().auth.admin.createUser({
    email,
    password: SENHA,
    email_confirm: true,
    user_metadata: { nome },
  });
  if (error) throw error;
  return email;
}

test("administrador recusa um pendente; a pessoa vê a tela de cadastro não aprovado", async ({ page }) => {
  const nome = `Recusada ${Date.now()}`;
  const email = await criarPendente(nome);

  await entrarCom(page, "admin@teste.local");
  await page.goto("/aprovacoes");
  await page.getByRole("button", { name: `Recusar ${nome}` }).click();
  await expect(page.getByText(nome)).toHaveCount(0);
  await sairDoApp(page);

  await entrarCom(page, email);
  await expect(page).toHaveURL(/\/cadastro-recusado/);
  await page.goto("/inicio");
  await expect(page).toHaveURL(/\/cadastro-recusado/);
});

test("pendente com email não confirmado não aparece na fila", async ({ page }) => {
  const nome = `NaoVerificada ${Date.now()}`;
  const { error } = await clienteAdmin().auth.admin.createUser({
    email: emailNovo("nv"),
    password: SENHA,
    email_confirm: false,
    user_metadata: { nome },
  });
  if (error) throw error;

  await entrarCom(page, "admin@teste.local");
  await page.goto("/aprovacoes");
  await expect(page.getByRole("heading", { name: "Pedidos e aprovações" })).toBeVisible();
  await expect(page.getByText(nome)).toHaveCount(0);
});

test("membro não acessa a tela de aprovação", async ({ page }) => {
  await entrarCom(page, "membro@teste.local");
  await page.goto("/aprovacoes");
  await expect(page).toHaveURL(/\/inicio/);
});
