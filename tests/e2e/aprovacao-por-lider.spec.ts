// T048 (História 4): o líder decide os pedidos de entrada dos ministérios que lidera; aceitar o
// pedido de uma conta nova também a ativa. Conta sem pedido só o administrador aprova.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, SENHA } from "./ajuda/email";
import { entrarCom } from "./ajuda/login";

const LOUVOR = "22222222-2222-2222-2222-222222222201";
const ID_LUCAS = "11111111-1111-1111-1111-111111111102";

// Conta nova pendente (email confirmado, como aparece na fila), opcionalmente com pedido ao Louvor.
async function criarPendente(prefixo: string, pedirLouvor: boolean) {
  const nome = `${prefixo} ${Date.now()}${Math.floor(Math.random() * 100)}`;
  const email = emailNovo("lider");
  const admin = clienteAdmin();
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: SENHA,
    email_confirm: true,
    user_metadata: { nome },
  });
  if (error) throw error;
  if (pedirLouvor) {
    const r = await admin.from("pedidos_entrada_ministerio").insert({ ministerio_id: LOUVOR, perfil_id: data.user.id });
    if (r.error) throw r.error;
  }
  return { nome, email, id: data.user.id };
}

test("líder aceita o pedido em até 2 toques: a conta fica ativa e a pessoa vira participante", async ({ page }) => {
  const pessoa = await criarPendente("Aceita", true);

  await entrarCom(page, "lider@teste.local");
  await expect(page).toHaveURL(/\/inicio/);
  await page.getByRole("link", { name: /Pedidos e aprovações/ }).first().click(); // toque 1
  await expect(page).toHaveURL(/\/aprovacoes/);
  await expect(page.getByText("Aceitar também ativa a conta").first()).toBeVisible();
  await page.getByRole("button", { name: `Aceitar ${pessoa.nome} em Louvor` }).click(); // toque 2
  await expect(page.getByText(pessoa.nome)).toHaveCount(0);

  const admin = clienteAdmin();
  const { data: conta } = await admin.from("perfis").select("situacao, papel").eq("id", pessoa.id).single();
  expect(conta).toEqual({ situacao: "aprovado", papel: "membro" });
  const { data: participacao } = await admin
    .from("participacoes_ministerio")
    .select("papel")
    .eq("perfil_id", pessoa.id)
    .eq("ministerio_id", LOUVOR)
    .single();
  expect(participacao?.papel).toBe("participante");

  // A pessoa já entra e vê o início.
  await page.context().clearCookies();
  await entrarCom(page, pessoa.email);
  await expect(page).toHaveURL(/\/inicio/);
});

test("recusar um pedido não recusa nem ativa a conta", async ({ page }) => {
  const pessoa = await criarPendente("Recusada", true);

  await entrarCom(page, "lider@teste.local");
  await page.goto("/aprovacoes");
  await page.getByRole("button", { name: `Recusar ${pessoa.nome} em Louvor` }).click();
  await expect(page.getByText(pessoa.nome)).toHaveCount(0);

  const admin = clienteAdmin();
  const { data: conta } = await admin.from("perfis").select("situacao").eq("id", pessoa.id).single();
  expect(conta?.situacao).toBe("pendente"); // continua aguardando (outro ministério ou administrador)
  const { data: pedido } = await admin.from("pedidos_entrada_ministerio").select("situacao").eq("perfil_id", pessoa.id).single();
  expect(pedido?.situacao).toBe("recusado");
});

test("conta sem ministério pedido não aparece para o líder; o administrador a aprova", async ({ page }) => {
  const pessoa = await criarPendente("SemPedido", false);

  await entrarCom(page, "lider@teste.local");
  await page.goto("/aprovacoes");
  await expect(page.getByRole("heading", { name: "Pedidos e aprovações" })).toBeVisible();
  await expect(page.getByText(pessoa.nome)).toHaveCount(0);
  await expect(page.getByRole("region", { name: "Cadastros pendentes" })).toHaveCount(0); // seção só do administrador
  await page.context().clearCookies();

  await entrarCom(page, "admin@teste.local");
  await page.goto("/aprovacoes");
  const cadastros = page.getByRole("region", { name: "Cadastros pendentes" });
  await expect(cadastros.getByText(pessoa.nome)).toBeVisible();
  await page.getByRole("button", { name: `Aprovar ${pessoa.nome}` }).click();
  await expect(page.getByText(pessoa.nome)).toHaveCount(0);

  const { data } = await clienteAdmin().from("perfis").select("situacao").eq("id", pessoa.id).single();
  expect(data?.situacao).toBe("aprovado");
});

test("dois decisores: quem decide depois é avisado e nada é sobrescrito", async ({ page }) => {
  const pessoa = await criarPendente("Conflito", true);

  await entrarCom(page, "lider@teste.local");
  await page.goto("/aprovacoes");
  await expect(page.getByText(pessoa.nome)).toBeVisible(); // a lista foi aberta com o pedido pendente

  // Enquanto isso, o administrador aceita o mesmo pedido.
  const admin = clienteAdmin();
  const { data: pedido } = await admin.from("pedidos_entrada_ministerio").select("id").eq("perfil_id", pessoa.id).single();
  await admin.from("perfis").update({ situacao: "aprovado" }).eq("id", pessoa.id);
  await admin.from("pedidos_entrada_ministerio").update({ situacao: "aceito" }).eq("id", pedido!.id);

  await page.getByRole("button", { name: `Recusar ${pessoa.nome} em Louvor` }).click();
  await expect(page.locator("p[role=alert]")).toContainText("Este pedido já foi decidido");

  const { data: depois } = await admin.from("pedidos_entrada_ministerio").select("situacao").eq("id", pedido!.id).single();
  expect(depois?.situacao).toBe("aceito"); // a recusa tardia não sobrescreveu
});

test("promover ou rebaixar um líder vale sem novo login (recarregando a página)", async ({ browser }) => {
  const admin = clienteAdmin();
  const nome = `Pessoa Lider ${Date.now()}`;
  const email = emailNovo("promo");
  const { data, error } = await admin.auth.admin.createUser({ email, password: SENHA, email_confirm: true, user_metadata: { nome } });
  if (error) throw error;
  await admin.from("perfis").update({ situacao: "aprovado" }).eq("id", data.user.id);

  // Ministério só deste teste, com Lucas como líder (para poder rebaixar a pessoa depois).
  const { data: min } = await admin.from("ministerios").insert({ nome: `Teste Promoção ${Date.now()}`, descricao: "" }).select("id").single();
  await admin.from("participacoes_ministerio").insert({ ministerio_id: min!.id, perfil_id: ID_LUCAS, papel: "lider" });

  const ctx = await browser.newContext();
  const pagina = await ctx.newPage();
  await entrarCom(pagina, email);
  await expect(pagina).toHaveURL(/\/inicio/);
  await expect(pagina.getByRole("link", { name: /Pedidos e aprovações/ })).toHaveCount(0);

  // Promovida a líder (sem sair do app): ao recarregar, a tela de líder aparece.
  await admin.from("participacoes_ministerio").insert({ ministerio_id: min!.id, perfil_id: data.user.id, papel: "lider" });
  await pagina.reload();
  await expect(pagina.getByRole("link", { name: /Pedidos e aprovações/ }).first()).toBeVisible();

  // Rebaixada: ao recarregar, perde o acesso à tela e é levada ao início.
  await admin.from("participacoes_ministerio").update({ papel: "participante" }).eq("ministerio_id", min!.id).eq("perfil_id", data.user.id);
  await pagina.goto("/aprovacoes");
  await expect(pagina).toHaveURL(/\/inicio/);
  await expect(pagina.getByRole("link", { name: /Pedidos e aprovações/ })).toHaveCount(0);
  await ctx.close();
});
