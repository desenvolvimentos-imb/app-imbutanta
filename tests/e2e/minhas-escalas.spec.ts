// T040 (História 3 da 003): "Minhas escalas": a pessoa escalada vê, confirma e recusa no próprio item;
// escala cancelada aparece sem botões; a tela vazia é amigável.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, SENHA } from "./ajuda/email";
import { entrarCom } from "./ajuda/login";

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
  const { data: m } = await admin.from("ministerios").insert({ nome: `Teste Minhas ${sufixo}`, descricao: "" }).select("id").single();
  if (!m) throw new Error("ministério não criado");
  const pessoa = await criarPessoa("Escalada", sufixo);
  await admin.from("participacoes_ministerio").insert([
    { ministerio_id: m.id, perfil_id: ID_LUCAS, papel: "lider" },
    { ministerio_id: m.id, perfil_id: pessoa.id, papel: "participante" },
  ]);
  const { data: funcoes } = await admin.from("funcoes_ministerio")
    .insert([{ ministerio_id: m.id, nome: "Vocal" }, { ministerio_id: m.id, nome: "Violão" }]).select("id, nome");
  const f = (nome: string) => funcoes?.find((x) => x.nome === nome)?.id;

  const { data: escalas } = await admin.from("escalas").insert([
    { ministerio_id: m.id, evento: `Culto A ${sufixo}`, data: diaEm(2), horario: "09:00", situacao: "publicada" },
    { ministerio_id: m.id, evento: `Culto B ${sufixo}`, data: diaEm(3), horario: "19:00", situacao: "publicada" },
    { ministerio_id: m.id, evento: `Culto Cancelado ${sufixo}`, data: diaEm(4), horario: "19:00", situacao: "cancelada" },
    { ministerio_id: m.id, evento: `Culto Rascunho ${sufixo}`, data: diaEm(5), horario: "19:00", situacao: "rascunho" },
    { ministerio_id: m.id, evento: `Culto Passado ${sufixo}`, data: diaEm(-7), horario: "19:00", situacao: "publicada" },
  ]).select("id, evento");
  const e = (prefixo: string) => escalas?.find((x) => x.evento.startsWith(prefixo))?.id;

  await admin.from("vagas_escala").insert([
    { escala_id: e("Culto A"), funcao_id: f("Vocal"), perfil_id: pessoa.id },
    { escala_id: e("Culto A"), funcao_id: f("Violão"), perfil_id: pessoa.id },
    { escala_id: e("Culto B"), funcao_id: f("Vocal"), perfil_id: pessoa.id },
    { escala_id: e("Culto Cancelado"), funcao_id: f("Vocal"), perfil_id: pessoa.id },
    { escala_id: e("Culto Rascunho"), funcao_id: f("Vocal"), perfil_id: pessoa.id },
    { escala_id: e("Culto Passado"), funcao_id: f("Vocal"), perfil_id: pessoa.id },
  ]);
  return { pessoa, sufixo, ministerioId: m.id as string, escalaA: e("Culto A") as string };
}

test("a pessoa escalada vê os itens, confirma e recusa no próprio item", async ({ page }) => {
  const c = await preparar();
  await entrarCom(page, c.pessoa.email);

  // Toque 1: Início → Minhas escalas (o contador mostra as 2 sem resposta)
  await expect(page.getByRole("link", { name: /Minhas escalas/ })).toContainText("2 sem resposta");
  await page.getByRole("link", { name: /Minhas escalas/ }).click();
  await expect(page).toHaveURL(/\/minhas-escalas/);
  await expect(page.getByRole("heading", { name: "Minhas escalas" })).toBeVisible();

  const a = page.getByRole("listitem").filter({ hasText: `Culto A ${c.sufixo}` });
  // O item mostra ministério, evento, funções (as duas, um só item), data/horário e resposta
  await expect(a).toContainText(`Teste Minhas ${c.sufixo}`);
  // (a ordem das funções segue a ordem das vagas; aqui o teste cria as duas com a mesma ordem)
  await expect(a).toContainText(/Função: (Vocal, Violão|Violão, Vocal)/);
  await expect(a).toContainText("às 09:00");
  await expect(a).toContainText("Pendente");

  // Rascunho nunca aparece; cancelada aparece sem botões
  await expect(page.getByText(`Culto Rascunho ${c.sufixo}`)).toHaveCount(0);
  const cancelada = page.getByRole("listitem").filter({ hasText: `Culto Cancelado ${c.sufixo}` });
  await expect(cancelada).toContainText("Cancelada");
  await expect(cancelada.getByRole("button")).toHaveCount(0);

  // Toque 2: confirmar no próprio item
  await a.getByRole("button", { name: `Confirmar presença: Culto A ${c.sufixo}` }).click();
  await expect(a).toContainText("Confirmado");

  // Recusar com motivo (muda a resposta, que vale para as duas vagas)
  await a.getByRole("button", { name: `Recusar: Culto A ${c.sufixo}` }).click();
  await a.getByLabel("Motivo (opcional)").fill("Viagem de trabalho");
  await a.getByRole("button", { name: `Confirmar recusa: Culto A ${c.sufixo}` }).click();
  await expect(a).toContainText("Recusado");
  await expect(a).toContainText("Motivo: Viagem de trabalho");

  // O líder vê a recusa e o motivo na escala
  await page.goto("/conta");
  await page.getByRole("button", { name: "Sair" }).click();
  await entrarCom(page, "lider@teste.local");
  await page.goto(`/ministerios/${c.ministerioId}/escalas/${c.escalaA}`);
  await expect(page.getByText("Recusou").first()).toBeVisible();
  await expect(page.getByText("Viagem de trabalho").first()).toBeVisible();

  // A passada fica em "Passadas"
  await page.goto("/conta");
  await page.getByRole("button", { name: "Sair" }).click();
  await entrarCom(page, c.pessoa.email);
  await page.goto("/minhas-escalas?passadas=1");
  await expect(page.getByText(`Culto Passado ${c.sufixo}`)).toBeVisible();
  await expect(page.getByRole("button", { name: /Confirmar presença/ })).toHaveCount(0);
});

test("quem não está escalado vê a tela vazia e amigável", async ({ page }) => {
  const pessoa = await criarPessoa("SemEscala", `${Date.now()}`);
  await entrarCom(page, pessoa.email);
  await page.goto("/minhas-escalas");
  await expect(page.getByText("Você não está escalado em nenhuma escala próxima.")).toBeVisible();
});
