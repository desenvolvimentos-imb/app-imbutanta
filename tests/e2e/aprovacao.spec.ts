// T046 (História 3): aprovar e recusar cadastros pendentes.
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

test("líder aprova um pendente em até 3 toques; a pessoa entra como membro", async ({ page }) => {
  const nome = `Aprovada ${Date.now()}`;
  const email = await criarPendente(nome);

  await entrarCom(page, "lider@teste.local");
  await expect(page).toHaveURL(/\/inicio/);
  await page.getByRole("link", { name: /Aprovar cadastros/ }).first().click(); // toque 1
  await expect(page).toHaveURL(/\/aprovacoes/);
  await page.getByRole("button", { name: `Aprovar ${nome}` }).click(); // toque 2
  await expect(page.getByText(nome)).toHaveCount(0);
  await sairDoApp(page);

  await entrarCom(page, email);
  await expect(page).toHaveURL(/\/inicio/);
  await expect(page.getByRole("link", { name: "Aprovar cadastros" })).toHaveCount(0);
});

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
  await expect(page.getByRole("heading", { name: "Aprovar cadastros" })).toBeVisible();
  await expect(page.getByText(nome)).toHaveCount(0);
});

test("membro não acessa a tela de aprovação", async ({ page }) => {
  await entrarCom(page, "membro@teste.local");
  await page.goto("/aprovacoes");
  await expect(page).toHaveURL(/\/inicio/);
});

test("dois aprovadores: quem decide depois é avisado e nada é sobrescrito", async ({ page }) => {
  const nome = `Conflito ${Date.now()}`;
  const email = await criarPendente(nome);

  await entrarCom(page, "lider@teste.local");
  await page.goto("/aprovacoes");
  await expect(page.getByText(nome)).toBeVisible(); // a lista foi aberta com a pessoa pendente

  // Enquanto isso, outro aprovador aprova a mesma pessoa.
  const admin = clienteAdmin();
  const { data: pessoa } = await admin.from("perfis").select("id").eq("email", email).single();
  await admin.from("perfis").update({ situacao: "aprovado" }).eq("id", pessoa!.id);

  await page.getByRole("button", { name: `Recusar ${nome}` }).click();
  await expect(page.locator("p[role=alert]")).toContainText("A situação desta pessoa mudou");

  const { data } = await admin.from("perfis").select("situacao").eq("id", pessoa!.id).single();
  expect(data?.situacao).toBe("aprovado"); // a recusa tardia não sobrescreveu
});
