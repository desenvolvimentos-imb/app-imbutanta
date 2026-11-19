// T057 (História 5): excluir a própria conta (LGPD).
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, SENHA } from "./ajuda/email";
import { entrarCom } from "./ajuda/login";

async function criarMembro(nome: string) {
  const admin = clienteAdmin();
  const email = emailNovo("excluir");
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: SENHA,
    email_confirm: true,
    user_metadata: { nome },
  });
  if (error) throw error;
  await admin.from("perfis").update({ situacao: "aprovado", papel: "membro" }).eq("id", data.user.id);
  return { email, id: data.user.id };
}

test("sem confirmar, nada é apagado; confirmando, a conta some e o login falha", async ({ page }) => {
  const { email, id } = await criarMembro("Pessoa Excluída");
  const admin = clienteAdmin();

  await entrarCom(page, email);
  await page.goto("/conta");
  await page.getByText("Excluir minha conta").click();

  // Tenta sem confirmar de verdade: nada é apagado.
  await page.getByLabel(/Digite EXCLUIR/).fill("excluir talvez");
  await page.getByRole("button", { name: "Excluir definitivamente" }).click();
  await expect(page.locator("p[role=alert]")).toContainText("EXCLUIR");
  expect((await admin.from("perfis").select("id").eq("id", id)).data).toHaveLength(1);

  // Confirma.
  await page.getByLabel(/Digite EXCLUIR/).fill("EXCLUIR");
  await page.getByRole("button", { name: "Excluir definitivamente" }).click();
  await expect(page).toHaveURL(/\/entrar/);
  await expect(page.getByText(/foram excluídos/i)).toBeVisible();

  expect((await admin.from("perfis").select("id").eq("id", id)).data).toHaveLength(0);

  // O login falha como se a conta nunca tivesse existido.
  await entrarCom(page, email, SENHA, false);
  await expect(page.locator("p[role=alert]")).toHaveText("Email ou senha incorretos.");

  // Pode criar nova conta, que começa pendente.
  const { data: novo, error } = await admin.auth.admin.createUser({
    email,
    password: SENHA,
    email_confirm: true,
    user_metadata: { nome: "Pessoa Nova" },
  });
  expect(error).toBeNull();
  const { data: perfil } = await admin.from("perfis").select("situacao").eq("id", novo!.user!.id).single();
  expect(perfil?.situacao).toBe("pendente");
});

test("pendente também pode excluir a conta, pela tela de espera", async ({ page }) => {
  const admin = clienteAdmin();
  const email = emailNovo("pendexcl");
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: SENHA,
    email_confirm: true,
    user_metadata: { nome: "Pendente Sai" },
  });
  if (error) throw error;

  await entrarCom(page, email);
  await expect(page).toHaveURL(/\/aguardando-aprovacao/);
  await page.getByText("Excluir minha conta").click();
  await page.getByLabel(/Digite EXCLUIR/).fill("EXCLUIR");
  await page.getByRole("button", { name: "Excluir definitivamente" }).click();
  await expect(page).toHaveURL(/\/entrar/);
  expect((await admin.from("perfis").select("id").eq("id", data.user.id)).data).toHaveLength(0);
});

test("o único administrador é impedido, com explicação", async ({ page }) => {
  const admin = clienteAdmin();
  const { data: admins } = await admin.from("perfis").select("id").eq("situacao", "aprovado").eq("papel", "administrador");
  test.skip(admins?.length !== 1, "Há mais de um administrador no banco local; o caso do único é coberto no pgTAP.");

  await entrarCom(page, "admin@teste.local");
  await page.goto("/conta");
  await page.getByText("Excluir minha conta").click();
  await page.getByLabel(/Digite EXCLUIR/).fill("EXCLUIR");
  await page.getByRole("button", { name: "Excluir definitivamente" }).click();

  await expect(page.locator("p[role=alert]")).toContainText("sem administrador");
  expect((await admin.from("perfis").select("id").eq("email", "admin@teste.local")).data).toHaveLength(1);
});
