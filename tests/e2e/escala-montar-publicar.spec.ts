// T029 (História 2 da 003): o líder cria a escala, preenche vagas (com avisos que não bloqueiam),
// publica; o participante a vê; o líder cancela e ela continua visível, marcada como cancelada.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, SENHA } from "./ajuda/email";
import { entrarCom, sairDoApp } from "./ajuda/login";

const ID_LUCAS = "11111111-1111-1111-1111-111111111102"; // lider@teste.local (seed)

// "Amanhã" em São Paulo, no formato AAAA-MM-DD.
function amanha() {
  const d = new Date(Date.now() + 24 * 60 * 60 * 1000);
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
  const { data: m } = await admin.from("ministerios").insert({ nome: `Teste Escala ${sufixo}`, descricao: "" }).select("id").single();
  const { data: m2 } = await admin.from("ministerios").insert({ nome: `Outro Ministerio ${sufixo}`, descricao: "" }).select("id").single();
  if (!m || !m2) throw new Error("ministérios não criados");

  const p1 = await criarPessoa("Apta", sufixo);
  const p2 = await criarPessoa("Semaptidao", sufixo);
  await admin.from("participacoes_ministerio").insert([
    { ministerio_id: m.id, perfil_id: ID_LUCAS, papel: "lider" },
    { ministerio_id: m.id, perfil_id: p1.id, papel: "participante" },
    { ministerio_id: m.id, perfil_id: p2.id, papel: "participante" },
    { ministerio_id: m2.id, perfil_id: ID_LUCAS, papel: "lider" },
    { ministerio_id: m2.id, perfil_id: p2.id, papel: "participante" },
  ]);

  const { data: funcoes } = await admin.from("funcoes_ministerio")
    .insert([{ ministerio_id: m.id, nome: "Vocal" }, { ministerio_id: m.id, nome: "Violão" }]).select("id, nome");
  const vocal = funcoes?.find((f) => f.nome === "Vocal")?.id;
  await admin.from("aptidoes").insert({ funcao_id: vocal, perfil_id: p1.id, tipo: "principal" });

  // Escala PUBLICADA de outro ministério, no mesmo dia, em que p2 já CONFIRMOU: gera o aviso.
  const dia = amanha();
  const { data: outra } = await admin.from("escalas")
    .insert({ ministerio_id: m2.id, evento: "Culto de domingo", data: dia, horario: "08:00", situacao: "publicada" }).select("id").single();
  const { data: funcao2 } = await admin.from("funcoes_ministerio").insert({ ministerio_id: m2.id, nome: "Recepção" }).select("id").single();
  await admin.from("vagas_escala").insert({ escala_id: outra?.id, funcao_id: funcao2?.id, perfil_id: p2.id });
  await admin.from("respostas_escala").insert({ escala_id: outra?.id, perfil_id: p2.id, resposta: "confirmado" });

  return { ministerioId: m.id as string, p1, p2, dia };
}

test("líder monta com avisos, publica; participante vê; cancelada continua visível", async ({ page }) => {
  const c = await preparar();

  // ===== Líder cria o rascunho =====
  await entrarCom(page, "lider@teste.local");
  await page.goto(`/ministerios/${c.ministerioId}/escalas/nova`);
  await page.getByLabel("Nome do evento").fill("Culto de louvor");
  await page.getByLabel("Data").fill(c.dia);
  await page.getByLabel("Horário de início").fill("19:00");
  await page.getByRole("button", { name: "Criar escala" }).click();
  await expect(page.getByRole("heading", { name: "Culto de louvor", level: 1 })).toBeVisible();
  await expect(page.getByText("Rascunho: só você e os administradores veem esta escala.")).toBeVisible();

  // ===== Vaga 1: Vocal 1 com p1 (apta, sem conflito) =====
  const nova = page.getByRole("region", { name: "Adicionar vaga" });
  await nova.getByLabel("Função").selectOption({ label: "Vocal" });
  await nova.getByLabel("Rótulo (opcional)").fill("Vocal 1");
  await nova.getByLabel("Pessoa").selectOption({ label: c.p1.nome });
  await nova.getByRole("button", { name: "Adicionar vaga" }).click();
  await expect(page.getByRole("heading", { name: /Vocal\s*·\s*Vocal 1/ })).toBeVisible();

  // ===== Vaga 2: Violão com p2 (sem aptidão E já confirmada em outro ministério no dia) =====
  await nova.getByLabel("Função").selectOption({ label: "Violão" });
  await nova.getByLabel("Rótulo (opcional)").fill("");
  await nova.getByLabel("Pessoa").selectOption({ label: c.p2.nome });
  await nova.getByRole("button", { name: "Adicionar vaga" }).click();
  const aviso = page.getByRole("alert").filter({ hasText: "Atenção" });
  await expect(aviso).toContainText("participante já escalado em outro ministério neste mesmo dia");
  await expect(aviso).toContainText("Culto de domingo");
  await expect(aviso).toContainText("08:00");
  await expect(aviso).toContainText("não está apta para a função Violão");
  await aviso.getByRole("button", { name: "Continuar mesmo assim" }).click();
  await expect(page.getByRole("heading", { name: "Violão" })).toBeVisible();

  // ===== Vaga 3: Vocal em aberto =====
  await nova.getByLabel("Função").selectOption({ label: "Vocal" });
  await nova.getByLabel("Pessoa").selectOption({ label: "Em aberto (sem pessoa)" });
  await nova.getByRole("button", { name: "Adicionar vaga" }).click();
  await expect(page.getByRole("heading", { name: "Vocal", exact: true })).toBeVisible();

  // ===== Publicar =====
  await expect(page.getByText("Há 1 vaga em aberto")).toBeVisible();
  await page.getByRole("button", { name: "Publicar escala" }).click();
  await expect(page.getByText("Publicada").first()).toBeVisible();
  const urlEscala = page.url();

  // ===== Participante vê, com os nomes e sem respostas dos outros =====
  await sairDoApp(page);
  await entrarCom(page, c.p1.email);
  await page.goto(urlEscala);
  await expect(page.getByRole("heading", { name: "Culto de louvor", level: 1 })).toBeVisible();
  await expect(page.getByText(c.p2.nome)).toBeVisible();
  await expect(page.getByText("Em aberto").first()).toBeVisible();
  await expect(page.getByText("Resposta:")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Publicar escala" })).toHaveCount(0);

  // ===== Líder cancela; a escala continua visível, marcada como cancelada =====
  await sairDoApp(page);
  await entrarCom(page, "lider@teste.local");
  await page.goto(urlEscala);
  await page.getByRole("button", { name: "Cancelar escala" }).click();
  await page.getByRole("button", { name: "Confirmar cancelamento" }).click();
  await expect(page.getByText("Esta escala foi cancelada.")).toBeVisible();

  await sairDoApp(page);
  await entrarCom(page, c.p1.email);
  await page.goto(urlEscala);
  await expect(page.getByText("Esta escala foi cancelada.")).toBeVisible();
});
