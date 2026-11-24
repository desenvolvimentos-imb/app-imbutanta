// T072 (História 6 da 003): visibilidade por papel e efeito da desativação do ministério.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, SENHA } from "./ajuda/email";
import { entrarCom, sairDoApp } from "./ajuda/login";

const ID_LUCAS = "11111111-1111-1111-1111-111111111102"; // lider@teste.local (seed)

function diaEm(dias: number) {
  const d = new Date(Date.now() + dias * 24 * 60 * 60 * 1000);
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/Sao_Paulo" }).format(d);
}

async function criarPessoa(prefixo: string, sufixo: string) {
  const admin = clienteAdmin();
  const nome = `${prefixo} ${sufixo}`;
  const email = emailNovo(prefixo.toLowerCase());
  const { data, error } = await admin.auth.admin.createUser({ email, password: SENHA, email_confirm: true, user_metadata: { nome } });
  if (error) throw error;
  await admin.from("perfis").update({ situacao: "aprovado" }).eq("id", data.user.id);
  return { id: data.user.id as string, nome, email };
}

async function preparar() {
  const admin = clienteAdmin();
  const sufixo = `${Date.now()}${Math.floor(Math.random() * 100)}`;
  const { data: m } = await admin.from("ministerios").insert({ nome: `Teste Visib ${sufixo}`, descricao: "" }).select("id").single();
  if (!m) throw new Error("ministério não criado");
  const [escalada, colega, estranha] = await Promise.all([
    criarPessoa("Escalada", sufixo), criarPessoa("Colega", sufixo), criarPessoa("Estranha", sufixo),
  ]);
  await admin.from("participacoes_ministerio").insert([
    { ministerio_id: m.id, perfil_id: ID_LUCAS, papel: "lider" },
    { ministerio_id: m.id, perfil_id: escalada.id, papel: "participante" },
    { ministerio_id: m.id, perfil_id: colega.id, papel: "participante" },
  ]);
  const { data: funcao } = await admin.from("funcoes_ministerio").insert({ ministerio_id: m.id, nome: "Vocal" }).select("id").single();
  const { data: escalas } = await admin.from("escalas").insert([
    { ministerio_id: m.id, evento: `Publicada ${sufixo}`, data: diaEm(3), horario: "19:00", situacao: "publicada" },
    { ministerio_id: m.id, evento: `Rascunho ${sufixo}`, data: diaEm(4), horario: "19:00", situacao: "rascunho" },
    { ministerio_id: m.id, evento: `Futura Dois ${sufixo}`, data: diaEm(6), horario: "19:00", situacao: "publicada" },
  ]).select("id, evento");
  const e = (p: string) => escalas?.find((x) => x.evento.startsWith(p))?.id as string;
  await admin.from("vagas_escala").insert([
    { escala_id: e("Publicada"), funcao_id: funcao?.id, rotulo: "V1", perfil_id: escalada.id, ordem: 1 },
    { escala_id: e("Futura Dois"), funcao_id: funcao?.id, rotulo: "V1", perfil_id: escalada.id, ordem: 1 },
  ]);
  await admin.from("respostas_escala").insert({ escala_id: e("Publicada"), perfil_id: escalada.id, resposta: "recusado", motivo: "Motivo reservado" });
  return { ministerioId: m.id as string, sufixo, escalada, colega, estranha, escalaPublicada: e("Publicada"), escalaRascunho: e("Rascunho") };
}

test("participante vê nomes, mas não respostas nem rascunho; estranho não vê nada", async ({ page }) => {
  const c = await preparar();

  // ===== Colega (participante sem vaga): vê a publicada, com o nome de quem ocupa; sem resposta =====
  await entrarCom(page, c.colega.email);
  await page.goto(`/ministerios/${c.ministerioId}/escalas`);
  await expect(page.getByText(`Publicada ${c.sufixo}`)).toBeVisible();
  await expect(page.getByText(`Rascunho ${c.sufixo}`)).toHaveCount(0);
  await page.goto(`/ministerios/${c.ministerioId}/escalas/${c.escalaPublicada}`);
  await expect(page.getByText(c.escalada.nome)).toBeVisible();
  await expect(page.getByText("Motivo reservado")).toHaveCount(0);
  await expect(page.getByText("Recusou")).toHaveCount(0);
  // Rascunho por acesso direto: "não encontrado"
  expect((await page.goto(`/ministerios/${c.ministerioId}/escalas/${c.escalaRascunho}`))?.status()).toBe(404);

  // ===== Estranha: nada, nem a lista nem a escala =====
  await sairDoApp(page);
  await entrarCom(page, c.estranha.email);
  expect((await page.goto(`/ministerios/${c.ministerioId}/escalas`))?.status()).toBe(404);
  expect((await page.goto(`/ministerios/${c.ministerioId}/escalas/${c.escalaPublicada}`))?.status()).toBe(404);
  expect((await page.goto(`/ministerios/${c.ministerioId}/funcoes`))?.status()).toBe(404);
});

test("administrador desativa o ministério: o app diz quantas escalas serão canceladas e só então cancela", async ({ page }) => {
  const c = await preparar();
  await entrarCom(page, "admin@teste.local");
  await page.goto(`/ministerios/${c.ministerioId}`);

  // 2 escalas publicadas + 1 rascunho, todas futuras
  await page.getByRole("button", { name: "Desativar ministério" }).click();
  await expect(page.getByText("Isto cancelará 3 escalas futuras")).toBeVisible();
  await page.getByRole("button", { name: "Confirmar desativação" }).click();
  await expect(page.getByText(/Ministério desativado/)).toBeVisible();

  // A escala continua visível, marcada como cancelada, para quem estava escalado
  await sairDoApp(page);
  await entrarCom(page, c.escalada.email);
  await page.goto("/minhas-escalas");
  await expect(page.getByRole("listitem").filter({ hasText: `Publicada ${c.sufixo}` })).toContainText("Cancelada");
});
