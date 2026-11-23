// T019 (História 1 da 003): o líder cria funções do ministério, define aptidões e desativa funções;
// quem não é gestor não vê a tela de gestão.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, SENHA } from "./ajuda/email";
import { entrarCom } from "./ajuda/login";

const ID_LUCAS = "11111111-1111-1111-1111-111111111102"; // lider@teste.local (seed)

// Ministério novo, só para este teste, liderado por Lucas, com um participante aprovado.
async function criarMinisterioComParticipante() {
  const admin = clienteAdmin();
  const sufixo = `${Date.now()}${Math.floor(Math.random() * 100)}`;
  const { data: ministerio, error } = await admin
    .from("ministerios").insert({ nome: `Teste Funcoes ${sufixo}`, descricao: "" }).select("id").single();
  if (error) throw error;
  await admin.from("participacoes_ministerio").insert({ ministerio_id: ministerio.id, perfil_id: ID_LUCAS, papel: "lider" });

  const nome = `Participante Apto ${sufixo}`;
  const email = emailNovo("apto");
  const { data: pessoa, error: erroPessoa } = await admin.auth.admin.createUser({
    email, password: SENHA, email_confirm: true, user_metadata: { nome },
  });
  if (erroPessoa) throw erroPessoa;
  await admin.from("perfis").update({ situacao: "aprovado" }).eq("id", pessoa.user.id);
  await admin.from("participacoes_ministerio").insert({ ministerio_id: ministerio.id, perfil_id: pessoa.user.id, papel: "participante" });
  return { id: ministerio.id as string, nomeParticipante: nome, emailParticipante: email };
}

test("líder cria funções, recusa nome repetido, define aptidões e desativa uma função", async ({ page }) => {
  const m = await criarMinisterioComParticipante();
  await entrarCom(page, "lider@teste.local");

  // Da página do ministério até as funções (atalho visível ao gestor)
  await page.goto(`/ministerios/${m.id}`);
  await page.getByRole("link", { name: "Funções e aptidões" }).click();
  await expect(page.getByRole("heading", { name: "Funções e aptidões" })).toBeVisible();

  // Cria "Vocal" e "Violão"
  await page.getByLabel("Nova função").fill("Vocal");
  await page.getByRole("button", { name: "Criar função" }).click();
  await expect(page.getByRole("listitem").filter({ hasText: "Vocal" }).first()).toBeVisible();
  await page.getByLabel("Nova função").fill("Violão");
  await page.getByRole("button", { name: "Criar função" }).click();
  await expect(page.getByRole("listitem").filter({ hasText: "Violão" }).first()).toBeVisible();

  // Nome repetido (caixa diferente): erro claro
  await page.getByLabel("Nova função").fill("vocal");
  await page.getByRole("button", { name: "Criar função" }).click();
  await expect(page.locator("p[role=alert]").first()).toContainText("Já existe uma função ativa com esse nome neste ministério.");

  // Aptidões do participante: Vocal principal e Violão secundária
  const cartao = page.getByRole("listitem").filter({ hasText: m.nomeParticipante });
  await cartao.getByLabel("Vocal").selectOption("principal");
  await cartao.getByLabel("Violão").selectOption("secundaria");
  await cartao.getByRole("button", { name: `Salvar aptidões de ${m.nomeParticipante}` }).click();
  await expect(cartao.getByText("Aptidões salvas.")).toBeVisible();
  await page.reload();
  await expect(page.getByRole("listitem").filter({ hasText: m.nomeParticipante }).getByLabel("Vocal")).toHaveValue("principal");
  await expect(page.getByRole("listitem").filter({ hasText: m.nomeParticipante }).getByLabel("Violão")).toHaveValue("secundaria");

  // Desativa "Violão" (duas etapas) e ela aparece como desativada, sem poder ser reescolhida
  await page.getByRole("button", { name: "Desativar a função Violão" }).click();
  await page.getByRole("button", { name: "Confirmar desativação: Violão" }).click();
  await expect(page.getByRole("button", { name: "Reativar a função Violão" })).toBeVisible();
});

test("membro comum não vê a tela de gestão de funções", async ({ page }) => {
  const m = await criarMinisterioComParticipante();
  await entrarCom(page, m.emailParticipante);

  // Sem atalho na página do ministério
  await page.goto(`/ministerios/${m.id}`);
  await expect(page.getByRole("link", { name: "Funções e aptidões" })).toHaveCount(0);

  // Acesso direto: "não encontrado" (a tela não revela nada)
  const resposta = await page.goto(`/ministerios/${m.id}/funcoes`);
  expect(resposta?.status()).toBe(404);
});
