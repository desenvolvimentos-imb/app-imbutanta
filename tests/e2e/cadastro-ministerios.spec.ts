// T040 (História 3): pedir entrada em ministérios no cadastro (email e senha) e na tela de
// espera (quem entra por Google não tem formulário de cadastro).
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, esperarEmail, extrairLink, SENHA } from "./ajuda/email";
import { entrarCom } from "./ajuda/login";

const LOUVOR = "22222222-2222-2222-2222-222222222201";
const RECEPCAO = "22222222-2222-2222-2222-222222222202";

async function idDoPerfil(email: string) {
  const { data } = await clienteAdmin().from("perfis").select("id").eq("email", email).single();
  return data!.id as string;
}

async function pedidosDe(perfilId: string) {
  const { data } = await clienteAdmin()
    .from("pedidos_entrada_ministerio")
    .select("ministerio_id, situacao, origem_cadastro")
    .eq("perfil_id", perfilId);
  return data ?? [];
}

test("sem ministérios ativos, a escolha de ministérios não aparece no cadastro", async ({ page }) => {
  const admin = clienteAdmin();
  const { data: ativos } = await admin.from("ministerios").select("id").eq("ativo", true);
  const ids = (ativos ?? []).map((m) => m.id as string);

  // Desativa tudo só durante o teste e SEMPRE restaura (a suíte compartilha o banco local).
  await admin.from("ministerios").update({ ativo: false, desativado_em: new Date().toISOString() }).in("id", ids);
  try {
    await page.goto("/cadastrar");
    await expect(page.getByLabel("Nome", { exact: true })).toBeVisible();
    await expect(page.getByText(/Ministérios de que você participa/)).toHaveCount(0);
  } finally {
    await admin.from("ministerios").update({ ativo: true, desativado_em: null }).in("id", ids);
  }
});

test("cadastro marcando Louvor e Recepção gera dois pedidos pendentes e nenhuma participação", async ({ page }) => {
  const email = emailNovo("cadmin");

  await page.goto("/cadastrar");
  await expect(page.getByText(/Ministérios de que você participa/)).toBeVisible();
  await page.getByLabel("Nome", { exact: true }).fill("Pessoa Com Pedidos");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Senha").fill(SENHA);
  await page.getByLabel("Louvor", { exact: true }).check();
  await page.getByLabel("Recepção", { exact: true }).check();
  await page.getByRole("button", { name: "Criar conta" }).click();
  await expect(page.getByText(/enviamos um link/i)).toBeVisible();

  await page.goto(extrairLink(await esperarEmail(email), "/auth/confirmar"));
  await expect(page).toHaveURL(/\/aguardando-aprovacao/);

  // A tela de espera mostra os pedidos feitos.
  const secao = page.getByRole("region", { name: "Ministérios que você pediu" });
  await expect(secao.getByText("Louvor")).toBeVisible();
  await expect(secao.getByText("Recepção")).toBeVisible();

  const perfil = await idDoPerfil(email);
  const pedidos = await pedidosDe(perfil);
  expect(pedidos.map((p) => p.ministerio_id).sort()).toEqual([LOUVOR, RECEPCAO]);
  expect(pedidos.every((p) => p.situacao === "pendente" && p.origem_cadastro)).toBe(true);
  const { data: participacoes } = await clienteAdmin().from("participacoes_ministerio").select("perfil_id").eq("perfil_id", perfil);
  expect(participacoes).toEqual([]); // marcar é só um pedido (RF-016)
});

test("cadastro sem marcar nenhum ministério também funciona", async ({ page }) => {
  const email = emailNovo("cadsem");
  await page.goto("/cadastrar");
  await page.getByLabel("Nome", { exact: true }).fill("Pessoa Sem Pedidos");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Senha").fill(SENHA);
  await page.getByRole("button", { name: "Criar conta" }).click();
  await page.goto(extrairLink(await esperarEmail(email), "/auth/confirmar"));
  await expect(page).toHaveURL(/\/aguardando-aprovacao/);
  expect(await pedidosDe(await idDoPerfil(email))).toEqual([]);
});

test("na tela de espera, quem não pediu nada pode pedir ministérios (fluxo do Google)", async ({ page }) => {
  const email = emailNovo("espera");
  const { error } = await clienteAdmin().auth.admin.createUser({
    email,
    password: SENHA,
    email_confirm: true,
    user_metadata: { nome: "Pessoa Na Espera" },
  });
  if (error) throw error;

  await entrarCom(page, email);
  await expect(page).toHaveURL(/\/aguardando-aprovacao/);

  await page.getByLabel("Louvor", { exact: true }).check();
  await page.getByRole("button", { name: "Enviar pedidos" }).click();

  const secao = page.getByRole("region", { name: "Ministérios que você pediu" });
  await expect(secao.getByText("Louvor")).toBeVisible();
  const pedidos = await pedidosDe(await idDoPerfil(email));
  expect(pedidos).toEqual([{ ministerio_id: LOUVOR, situacao: "pendente", origem_cadastro: true }]);
});
