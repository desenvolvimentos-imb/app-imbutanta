// T062 (História 6): gerir papéis e acesso. Só o administrador acessa a tela de usuários.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, SENHA } from "./ajuda/email";
import { entrarCom } from "./ajuda/login";

type Situacao = "pendente" | "aprovado" | "recusado" | "acesso_removido";

// Espera (até 5 s) o papel gravado no banco ficar igual ao esperado: a ação do servidor é assíncrona.
async function esperarPapel(id: string, papel: string) {
  await expect
    .poll(async () => (await clienteAdmin().from("perfis").select("papel").eq("id", id).single()).data?.papel)
    .toBe(papel);
}

// Cria uma pessoa com a situação desejada (nome único, para não mexer nas contas do seed).
async function criarPessoa(prefixo: string, situacao: Situacao = "aprovado") {
  const nome = `${prefixo} ${Date.now()}${Math.floor(Math.random() * 100)}`;
  const email = emailNovo("papeis");
  const admin = clienteAdmin();
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: SENHA,
    email_confirm: true,
    user_metadata: { nome },
  });
  if (error) throw error;
  await admin.from("perfis").update({ situacao, papel: "membro" }).eq("id", data.user.id);
  return { nome, email, id: data.user.id };
}

test("administrador promove membro a líder; o líder conectado vê a mudança sem novo login", async ({ browser, page }) => {
  const pessoa = await criarPessoa("Promovida");

  // A pessoa já está conectada como membro, em outro aparelho.
  const ctxPessoa = await browser.newContext();
  const paginaPessoa = await ctxPessoa.newPage();
  await entrarCom(paginaPessoa, pessoa.email);
  await expect(paginaPessoa).toHaveURL(/\/inicio/);
  await expect(paginaPessoa.getByRole("link", { name: "Aprovar cadastros" })).toHaveCount(0);

  // O administrador muda o papel.
  await entrarCom(page, "admin@teste.local");
  await page.goto("/usuarios");
  await page.getByLabel(`Papel de ${pessoa.nome}`, { exact: true }).selectOption("lider");
  await page.getByRole("button", { name: `Alterar papel de ${pessoa.nome}` }).click();
  await esperarPapel(pessoa.id, "lider");

  // Sem sair e entrar de novo, basta atualizar.
  await paginaPessoa.reload();
  await expect(paginaPessoa.getByRole("link", { name: "Aprovar cadastros" }).first()).toBeVisible();

  // Volta a membro e a mudança também vale na hora.
  await page.getByLabel(`Papel de ${pessoa.nome}`, { exact: true }).selectOption("membro");
  await page.getByRole("button", { name: `Alterar papel de ${pessoa.nome}` }).click();
  await esperarPapel(pessoa.id, "membro");
  await paginaPessoa.goto("/aprovacoes");
  await expect(paginaPessoa).toHaveURL(/\/inicio/);
  await ctxPessoa.close();
});

test("líder e membro não acessam a gestão de usuários", async ({ page }) => {
  await entrarCom(page, "lider@teste.local");
  await page.goto("/usuarios");
  await expect(page).toHaveURL(/\/inicio/);
  await page.context().clearCookies();

  await entrarCom(page, "membro@teste.local");
  await page.goto("/usuarios");
  await expect(page).toHaveURL(/\/inicio/);
});

test("remover e restaurar acesso; reaprovar cadastro recusado", async ({ browser, page }) => {
  const pessoa = await criarPessoa("Acesso");
  const recusada = await criarPessoa("Recusada", "recusado");

  const ctx = await browser.newContext();
  const paginaPessoa = await ctx.newPage();
  await entrarCom(paginaPessoa, pessoa.email);
  await expect(paginaPessoa).toHaveURL(/\/inicio/);

  await entrarCom(page, "admin@teste.local");
  await page.goto("/usuarios");

  await page.getByRole("button", { name: `Remover acesso de ${pessoa.nome}` }).click();
  await expect(page.getByRole("button", { name: `Restaurar acesso de ${pessoa.nome}` })).toBeVisible();
  await paginaPessoa.goto("/inicio");
  await expect(paginaPessoa).toHaveURL(/\/acesso-removido/);

  await page.getByRole("button", { name: `Restaurar acesso de ${pessoa.nome}` }).click();
  await expect(page.getByRole("button", { name: `Remover acesso de ${pessoa.nome}` })).toBeVisible();
  await paginaPessoa.goto("/inicio");
  await expect(paginaPessoa).toHaveURL(/\/inicio/);

  await page.getByRole("button", { name: `Reaprovar ${recusada.nome}` }).click();
  await expect(page.getByRole("button", { name: `Reaprovar ${recusada.nome}` })).toHaveCount(0);
  const { data } = await clienteAdmin().from("perfis").select("situacao, papel").eq("id", recusada.id).single();
  expect(data).toEqual({ situacao: "aprovado", papel: "membro" });
  await ctx.close();
});

test("o único administrador não consegue rebaixar-se nem remover o próprio acesso", async ({ page }) => {
  const admin = clienteAdmin();
  const { data: admins } = await admin.from("perfis").select("id").eq("situacao", "aprovado").eq("papel", "administrador");
  test.skip(admins?.length !== 1, "Há mais de um administrador no banco local; o caso é coberto no pgTAP.");

  await entrarCom(page, "admin@teste.local");
  await page.goto("/usuarios");

  await page.getByLabel("Papel de Ana Administradora", { exact: true }).selectOption("membro");
  await page.getByRole("button", { name: "Alterar papel de Ana Administradora" }).click();
  await expect(page.locator("p[role=alert]")).toContainText("sem administrador");

  await page.getByRole("button", { name: "Remover acesso de Ana Administradora" }).click();
  await expect(page.locator("p[role=alert]")).toContainText("sem administrador");

  const { data } = await admin.from("perfis").select("papel, situacao").eq("email", "admin@teste.local").single();
  expect(data).toEqual({ papel: "administrador", situacao: "aprovado" });
});
