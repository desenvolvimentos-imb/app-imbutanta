// T050 (História 4 da 003): o líder acompanha respostas, vê destaques, troca pessoas, muda o horário
// (respostas voltam a pendente) e, ao remover um participante, vê as vagas dele em aberto.
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
  const { data, error } = await admin.auth.admin.createUser({
    email: emailNovo(prefixo.toLowerCase()), password: SENHA, email_confirm: true, user_metadata: { nome },
  });
  if (error) throw error;
  await admin.from("perfis").update({ situacao: "aprovado" }).eq("id", data.user.id);
  return { id: data.user.id as string, nome };
}

async function preparar() {
  const admin = clienteAdmin();
  const sufixo = `${Date.now()}${Math.floor(Math.random() * 100)}`;
  const { data: m } = await admin.from("ministerios").insert({ nome: `Teste Acompanha ${sufixo}`, descricao: "" }).select("id").single();
  if (!m) throw new Error("ministério não criado");
  const [p1, p2, p3, p4] = await Promise.all(["Alfa", "Bravo", "Charlie", "Delta"].map((n) => criarPessoa(n, sufixo)));
  await admin.from("participacoes_ministerio").insert([
    { ministerio_id: m.id, perfil_id: ID_LUCAS, papel: "lider" },
    ...[p1, p2, p3, p4].map((p) => ({ ministerio_id: m.id, perfil_id: p.id, papel: "participante" })),
  ]);
  const { data: funcao } = await admin.from("funcoes_ministerio").insert({ ministerio_id: m.id, nome: "Vocal" }).select("id").single();
  const { data: escala } = await admin.from("escalas")
    .insert({ ministerio_id: m.id, evento: `Culto ${sufixo}`, data: diaEm(3), horario: "19:00", situacao: "publicada" })
    .select("id").single();
  const r1 = await admin.from("vagas_escala").insert([
    { escala_id: escala?.id, funcao_id: funcao?.id, rotulo: "V1", perfil_id: p1.id, ordem: 1 },
    { escala_id: escala?.id, funcao_id: funcao?.id, rotulo: "V2", perfil_id: p2.id, ordem: 2 },
    { escala_id: escala?.id, funcao_id: funcao?.id, rotulo: "V3", perfil_id: p3.id, ordem: 3 },
  ]);
  if (r1.error) throw r1.error;
  const r2 = await admin.from("respostas_escala").insert([
    { escala_id: escala?.id, perfil_id: p1.id, resposta: "confirmado", motivo: "" },
    { escala_id: escala?.id, perfil_id: p2.id, resposta: "recusado", motivo: "Motivo da recusa" },
  ]);
  if (r2.error) throw r2.error;
  return { ministerioId: m.id as string, escalaId: escala?.id as string, p1, p2, p3, p4 };
}

test("líder vê destaques, troca a pessoa, muda o horário e remove um participante", async ({ page }) => {
  const c = await preparar();
  await entrarCom(page, "lider@teste.local");
  await page.goto(`/ministerios/${c.ministerioId}`);
  // Nenhuma vaga em aberto ainda: sem aviso na página do ministério
  await expect(page.getByText(/escalas? (tem|têm) vagas em aberto/)).toHaveCount(0);

  const vaga = (rotulo: string) =>
    page.getByRole("listitem").filter({ has: page.getByRole("heading", { name: new RegExp(`· ${rotulo}$`) }) });

  // ===== Destaques e motivo de recusa =====
  await page.goto(`/ministerios/${c.ministerioId}/escalas/${c.escalaId}`);
  await expect(vaga("V1")).toContainText("Resposta: Confirmado");
  await expect(vaga("V1")).not.toContainText("Recusou");
  await expect(vaga("V2")).toContainText("Recusou");
  await expect(vaga("V2")).toContainText("Motivo da recusa");
  await expect(vaga("V3")).toContainText("Sem resposta");

  // ===== Trocar a pessoa da vaga recusada (a nova não tem aptidão: aviso, e o líder continua) =====
  await vaga("V2").getByLabel("Pessoa").selectOption({ label: c.p4.nome });
  await vaga("V2").getByRole("button", { name: /Salvar vaga Vocal V2/ }).click();
  await expect(vaga("V2")).toContainText("não está apta para a função Vocal");
  await vaga("V2").getByRole("button", { name: "Continuar mesmo assim" }).click();
  await expect(vaga("V2")).not.toContainText("Recusou");
  await expect(vaga("V2")).toContainText("Sem resposta"); // a nova pessoa está pendente
  await expect(vaga("V1")).toContainText("Resposta: Confirmado"); // as outras respostas ficam

  // ===== Mudar o horário: todas as respostas voltam a pendente =====
  await page.getByLabel("Horário de início").fill("21:00");
  await page.getByRole("button", { name: "Salvar alterações" }).click();
  await expect(page.getByText("Alterações salvas.")).toBeVisible();
  await expect(vaga("V1")).toContainText("Resposta: Pendente");
  await expect(vaga("V1")).toContainText("Sem resposta");
  await expect(vaga("V3")).toContainText("Resposta: Pendente");

  // ===== Remover um participante do ministério: as vagas futuras dele ficam em aberto =====
  await page.goto(`/ministerios/${c.ministerioId}`);
  await page.getByRole("button", { name: `Remover ${c.p1.nome}` }).click();
  await page.getByRole("button", { name: `Confirmar remoção: ${c.p1.nome}` }).click();
  await expect(page.getByText("1 escala tem vagas em aberto.")).toBeVisible();

  await page.goto(`/ministerios/${c.ministerioId}/escalas/${c.escalaId}`);
  await expect(vaga("V1")).toContainText("Em aberto");
});
