// T062 (História 5 da 003): a pessoa escalada pede troca, a indicada aceita, o líder aprova (com
// aviso e "continuar mesmo assim") e a vaga passa para a indicada com resposta "confirmado".
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
  const { data: m } = await admin.from("ministerios").insert({ nome: `Teste Troca ${sufixo}`, descricao: "" }).select("id").single();
  if (!m) throw new Error("ministério não criado");
  const [p1, p2] = await Promise.all([criarPessoa("Alfa", sufixo), criarPessoa("Bravo", sufixo)]);
  await admin.from("participacoes_ministerio").insert([
    { ministerio_id: m.id, perfil_id: ID_LUCAS, papel: "lider" },
    { ministerio_id: m.id, perfil_id: p1.id, papel: "participante" },
    { ministerio_id: m.id, perfil_id: p2.id, papel: "participante" },
  ]);
  const { data: funcao } = await admin.from("funcoes_ministerio").insert({ ministerio_id: m.id, nome: "Vocal" }).select("id").single();
  const evento = `Culto Troca ${sufixo}`;
  const { data: escala } = await admin.from("escalas")
    .insert({ ministerio_id: m.id, evento, data: diaEm(3), horario: "19:00", situacao: "publicada" }).select("id").single();
  await admin.from("vagas_escala").insert({ escala_id: escala?.id, funcao_id: funcao?.id, rotulo: "Vocal 1", perfil_id: p1.id, ordem: 1 });
  await admin.from("respostas_escala").insert({ escala_id: escala?.id, perfil_id: p1.id, resposta: "confirmado", motivo: "" });
  return { ministerioId: m.id as string, escalaId: escala?.id as string, evento, p1, p2 };
}

test("pedir, cancelar, pedir de novo, aceitar, aprovar com aviso e conferir a vaga", async ({ page }) => {
  const c = await preparar();
  const urlEscala = `/ministerios/${c.ministerioId}/escalas/${c.escalaId}`;

  // ===== P1 pede a troca =====
  await entrarCom(page, c.p1.email);
  await page.goto(urlEscala);
  await page.getByRole("button", { name: /Pedir troca da vaga Vocal/ }).click();
  await page.getByLabel("Quem vai assumir a vaga").selectOption({ label: c.p2.nome });
  await page.getByRole("button", { name: /Enviar pedido de troca/ }).click();
  await expect(page.getByText(`Pedido para ${c.p2.nome}.`)).toBeVisible();
  // Já tem pedido em andamento: não oferece outro para a mesma vaga
  await expect(page.getByRole("button", { name: /Pedir troca da vaga/ })).toHaveCount(0);

  // ===== P1 cancela e pede de novo =====
  await page.goto("/pedidos-de-troca");
  const feito = page.getByRole("listitem").filter({ hasText: c.evento });
  await expect(feito).toContainText("Aguardando a pessoa indicada");
  await feito.getByRole("button", { name: /Cancelar pedido de troca/ }).click();
  await expect(page.getByRole("region", { name: /Histórico/ }).getByRole("listitem").filter({ hasText: c.evento })).toContainText("Cancelado");
  await page.goto(urlEscala);
  await page.getByRole("button", { name: /Pedir troca da vaga Vocal/ }).click();
  await page.getByLabel("Quem vai assumir a vaga").selectOption({ label: c.p2.nome });
  await page.getByRole("button", { name: /Enviar pedido de troca/ }).click();
  await expect(page.getByText(`Pedido para ${c.p2.nome}.`)).toBeVisible();

  // ===== P2 (a indicada) aceita =====
  await sairDoApp(page);
  await entrarCom(page, c.p2.email);
  await page.goto("/pedidos-de-troca");
  const recebido = page.getByRole("region", { name: /Recebidos/ }).getByRole("listitem").filter({ hasText: c.evento });
  await recebido.getByRole("button", { name: `Aceitar o pedido de ${c.p1.nome}` }).click();
  // (o primeiro pedido, cancelado, também aparece para a indicada no histórico)
  await expect(page.getByRole("region", { name: /Histórico/ }).getByRole("listitem").filter({ hasText: "Aguardando o líder" })).toHaveCount(1);

  // ===== O líder aprova: aviso de aptidão, e continua =====
  await sairDoApp(page);
  await entrarCom(page, "lider@teste.local");
  await page.goto("/pedidos-de-troca");
  const aAprovar = page.getByRole("region", { name: /Aguardando minha aprovação/ }).getByRole("listitem").filter({ hasText: c.evento });
  await aAprovar.getByRole("button", { name: /Aprovar a troca/ }).click();
  await expect(aAprovar).toContainText("não está apta para a função Vocal");
  await aAprovar.getByRole("button", { name: "Continuar mesmo assim" }).click();
  // Decidido, o pedido sai da fila do líder (o histórico é de quem pediu e de quem foi indicada).
  await expect(aAprovar).toHaveCount(0);

  // ===== A vaga passou para P2, com "confirmado"; P1 deixou a vaga =====
  await sairDoApp(page);
  await entrarCom(page, c.p2.email);
  await page.goto("/minhas-escalas");
  const item = page.getByRole("listitem").filter({ hasText: c.evento });
  await expect(item).toContainText("Confirmado");
  await sairDoApp(page);
  await entrarCom(page, c.p1.email);
  await page.goto("/minhas-escalas");
  await expect(page.getByText(c.evento)).toHaveCount(0);
});

test("a tela de pedidos de troca é amigável para quem não tem nenhum", async ({ page }) => {
  const pessoa = await criarPessoa("SemPedidos", `${Date.now()}`);
  await entrarCom(page, pessoa.email);
  await page.goto("/pedidos-de-troca");
  await expect(page.getByRole("heading", { name: "Pedidos de troca" })).toBeVisible();
  await expect(page.getByText("Ninguém pediu que você assuma uma vaga.")).toBeVisible();
  await expect(page.getByText("Você não tem pedidos de troca em andamento.")).toBeVisible();
});
