// T034 (História 2): o líder gerencia os participantes do próprio ministério, e só dele;
// todo ministério mantém pelo menos um líder.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, SENHA } from "./ajuda/email";
import { entrarCom } from "./ajuda/login";

const ID_LUCAS = "11111111-1111-1111-1111-111111111102"; // lider@teste.local (seed)
const ID_RECEPCAO = "22222222-2222-2222-2222-222222222202"; // ministério que Lucas NÃO lidera (seed)

// Pessoa aprovada, com nome único, para aparecer na busca.
async function criarPessoaAprovada(prefixo: string) {
  const nome = `${prefixo} ${Date.now()}${Math.floor(Math.random() * 100)}`;
  const admin = clienteAdmin();
  const { data, error } = await admin.auth.admin.createUser({
    email: emailNovo("part"),
    password: SENHA,
    email_confirm: true,
    user_metadata: { nome },
  });
  if (error) throw error;
  await admin.from("perfis").update({ situacao: "aprovado" }).eq("id", data.user.id);
  return { nome, id: data.user.id };
}

// Ministério novo, só para este teste, liderado por Lucas (não mexe nos ministérios do seed).
async function criarMinisterioDoLucas() {
  const nome = `Teste Participantes ${Date.now()}`;
  const admin = clienteAdmin();
  const { data, error } = await admin.from("ministerios").insert({ nome, descricao: "" }).select("id").single();
  if (error) throw error;
  await admin.from("participacoes_ministerio").insert({ ministerio_id: data.id, perfil_id: ID_LUCAS, papel: "lider" });
  return { nome, id: data.id as string };
}

test("líder busca, adiciona, promove e rebaixa; o último líder não sai", async ({ page }) => {
  const pessoa = await criarPessoaAprovada("Zeferina");
  const ministerio = await criarMinisterioDoLucas();

  await entrarCom(page, "lider@teste.local");
  await page.goto(`/ministerios/${ministerio.id}`);

  // Buscar e adicionar como participante
  await page.getByLabel("Buscar pessoa por nome").fill(pessoa.nome.split(" ")[0]);
  await page.getByRole("button", { name: "Buscar" }).click();
  await page.getByRole("button", { name: `Adicionar ${pessoa.nome}` }).click();
  const linhaPessoa = page.getByRole("listitem").filter({ hasText: pessoa.nome });
  await expect(linhaPessoa).toContainText("Participante");

  // Lucas é o único líder: rebaixar a si mesmo é impedido, com a mensagem clara.
  await page.getByRole("button", { name: "Rebaixar Lucas Líder a participante" }).click();
  await expect(page.locator("p[role=alert]")).toContainText(/O ministério .+ precisa de pelo menos um líder/);

  // Promove a pessoa a líder; agora Lucas pode ser rebaixado.
  await page.getByRole("button", { name: `Promover ${pessoa.nome} a líder` }).click();
  await expect(linhaPessoa).toContainText("Líder");
  await page.getByRole("button", { name: "Rebaixar Lucas Líder a participante" }).click();
  // Ao se rebaixar, Lucas perde os controles de gestão: espera isso aparecer na tela (sinal de que a
  // ação terminou) antes de conferir o resultado, em vez de confiar só no tempo.
  await expect(page.getByLabel("Buscar pessoa por nome")).toHaveCount(0);
  await expect(page.getByRole("listitem").filter({ hasText: "Lucas Líder" })).toContainText("Participante");

  // Sem ser mais líder, Lucas perde os controles de gestão deste ministério.
  await page.reload();
  await expect(page.getByLabel("Buscar pessoa por nome")).toHaveCount(0);
});

test("líder remove um participante comum, em duas etapas", async ({ page }) => {
  const pessoa = await criarPessoaAprovada("Remocao");
  const ministerio = await criarMinisterioDoLucas();
  await clienteAdmin()
    .from("participacoes_ministerio")
    .insert({ ministerio_id: ministerio.id, perfil_id: pessoa.id, papel: "participante" });

  await entrarCom(page, "lider@teste.local");
  await page.goto(`/ministerios/${ministerio.id}`);
  await page.getByRole("button", { name: `Remover ${pessoa.nome}` }).click();
  await page.getByRole("button", { name: `Confirmar remoção: ${pessoa.nome}` }).click();
  await expect(page.getByText(pessoa.nome)).toHaveCount(0);
});

test("o líder do Louvor não vê controles de gestão na Recepção", async ({ page }) => {
  await entrarCom(page, "lider@teste.local");
  await page.goto(`/ministerios/${ID_RECEPCAO}`);
  await expect(page.getByRole("heading", { name: "Recepção" })).toBeVisible();
  await expect(page.getByLabel("Buscar pessoa por nome")).toHaveCount(0);
  await expect(page.getByRole("button", { name: /Promover|Rebaixar|Remover/ })).toHaveCount(0);
});

test("excluir a conta da única líder de um ministério é impedido; depois de definir outro líder, passa", async ({ page }) => {
  const lider = await criarPessoaAprovada("Lider Unica");
  const substituta = await criarPessoaAprovada("Substituta");
  const nomeMinisterio = `Teste Exclusão ${Date.now()}`;
  const admin = clienteAdmin();
  const { data: min, error } = await admin.from("ministerios").insert({ nome: nomeMinisterio, descricao: "" }).select("id").single();
  if (error) throw error;
  await admin.from("participacoes_ministerio").insert([
    { ministerio_id: min.id, perfil_id: lider.id, papel: "lider" },
    { ministerio_id: min.id, perfil_id: substituta.id, papel: "participante" },
  ]);
  const { data: conta } = await admin.from("perfis").select("email").eq("id", lider.id).single();

  await entrarCom(page, conta!.email);
  await page.goto("/conta");
  await page.getByText("Excluir minha conta").click();
  await page.getByLabel(/Digite EXCLUIR/).fill("EXCLUIR");
  await page.getByRole("button", { name: "Excluir definitivamente" }).click();

  // Barrado pelo banco, citando o ministério (RF-013).
  await expect(page.locator("p[role=alert]")).toContainText(nomeMinisterio);
  await expect(page.locator("p[role=alert]")).toContainText("precisa de pelo menos um líder");
  expect((await admin.from("perfis").select("id").eq("id", lider.id)).data).toHaveLength(1);

  // Um administrador define outro líder; agora a exclusão passa e leva vínculos junto.
  await admin.from("participacoes_ministerio").update({ papel: "lider" }).eq("ministerio_id", min.id).eq("perfil_id", substituta.id);
  await page.getByLabel(/Digite EXCLUIR/).fill("EXCLUIR");
  await page.getByRole("button", { name: "Excluir definitivamente" }).click();
  await expect(page).toHaveURL(/\/entrar/);
  expect((await admin.from("perfis").select("id").eq("id", lider.id)).data).toHaveLength(0);
  expect((await admin.from("participacoes_ministerio").select("perfil_id").eq("perfil_id", lider.id)).data).toEqual([]);
});
