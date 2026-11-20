// T054 (História 5): "Meus ministérios": estado vazio, pedir entrada, acompanhar, cancelar e
// pedir de novo, inclusive depois de um pedido recusado.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, SENHA } from "./ajuda/email";
import { entrarCom } from "./ajuda/login";

const LOUVOR = "22222222-2222-2222-2222-222222222201";

// Membro aprovado, sem nenhum ministério.
async function criarMembroSemMinisterio() {
  const nome = `Sem Ministerio ${Date.now()}${Math.floor(Math.random() * 100)}`;
  const email = emailNovo("meus");
  const admin = clienteAdmin();
  const { data, error } = await admin.auth.admin.createUser({ email, password: SENHA, email_confirm: true, user_metadata: { nome } });
  if (error) throw error;
  await admin.from("perfis").update({ situacao: "aprovado" }).eq("id", data.user.id);
  return { nome, email, id: data.user.id };
}

test("quem não participa de nenhum ministério vê a tela vazia, pede entrada, cancela e pede de novo", async ({ page }) => {
  const pessoa = await criarMembroSemMinisterio();
  await entrarCom(page, pessoa.email);
  await expect(page).toHaveURL(/\/inicio/);

  // Toque 1: Início → Meus ministérios (estado vazio amigável, sem erro)
  await page.getByRole("link", { name: "Meus ministérios" }).first().click();
  await expect(page).toHaveURL(/\/meus-ministerios/);
  await expect(page.getByRole("heading", { name: "Meus ministérios" })).toBeVisible();
  await expect(page.getByText("Você ainda não participa de nenhum ministério.")).toBeVisible();

  // Toque 2: pedir entrada na Recepção (3 toques no máximo desde o início)
  await page.getByRole("button", { name: "Pedir para entrar em Recepção" }).click();
  const pedidos = page.getByRole("region", { name: "Meus pedidos" });
  await expect(pedidos.getByText("Recepção")).toBeVisible();
  await expect(pedidos.getByText("Aguardando o líder")).toBeVisible();
  // O ministério com pedido pendente não é oferecido de novo (sem duplicidade).
  await expect(page.getByRole("button", { name: "Pedir para entrar em Recepção" })).toHaveCount(0);

  // Cancelar e pedir de novo
  await page.getByRole("button", { name: "Cancelar pedido de Recepção" }).click();
  await expect(pedidos).toHaveCount(0);
  await page.getByRole("button", { name: "Pedir para entrar em Recepção" }).click();
  await expect(pedidos.getByText("Aguardando o líder")).toBeVisible();
});

test("pedido recusado aparece como recusado e permite um novo pedido", async ({ page }) => {
  const pessoa = await criarMembroSemMinisterio();
  const admin = clienteAdmin();
  await admin.from("pedidos_entrada_ministerio").insert({
    ministerio_id: LOUVOR,
    perfil_id: pessoa.id,
    situacao: "recusado",
    decidido_em: new Date().toISOString(),
  });

  await entrarCom(page, pessoa.email);
  await page.goto("/meus-ministerios");
  const pedidos = page.getByRole("region", { name: "Meus pedidos" });
  await expect(pedidos.getByText("Louvor")).toBeVisible();
  await expect(pedidos.getByText("Recusado")).toBeVisible();

  await page.getByRole("button", { name: "Pedir para entrar em Louvor" }).click();
  await expect(pedidos.getByText("Aguardando o líder")).toBeVisible();
  const { data } = await admin.from("pedidos_entrada_ministerio").select("situacao").eq("perfil_id", pessoa.id).eq("ministerio_id", LOUVOR);
  expect((data ?? []).map((p) => p.situacao).sort()).toEqual(["pendente", "recusado"]);
});

test("participante vê o ministério com o papel e quem faz parte dele", async ({ page }) => {
  await entrarCom(page, "membro@teste.local"); // Marta: participante do Louvor no seed
  await page.goto("/meus-ministerios");
  const louvor = page.getByRole("region", { name: "Louvor" });
  await expect(louvor.getByText("Participante", { exact: true }).first()).toBeVisible();
  await expect(louvor.getByText("Lucas Líder")).toBeVisible(); // o líder aparece na lista de quem faz parte
});

test("administrador vê em Meus ministérios só os próprios vínculos e pedidos, não os de todo mundo", async ({ page }) => {
  // A RLS deixa o administrador ler TODAS as participações; a tela precisa filtrar pela própria pessoa.
  await entrarCom(page, "admin@teste.local"); // lidera só a Recepção no seed
  await page.goto("/meus-ministerios");
  await expect(page.getByRole("region", { name: "Recepção" })).toBeVisible();
  await expect(page.getByRole("region", { name: "Louvor" })).toHaveCount(0); // Louvor é de Lucas e Marta
  await expect(page.getByRole("region", { name: "Meus pedidos" })).toHaveCount(0); // o pedido do Paulo não é dele
});
