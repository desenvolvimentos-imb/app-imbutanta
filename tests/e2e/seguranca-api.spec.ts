// T066 (RF-020, CS-004): as regras valem mesmo SEM passar pela interface. Aqui falamos direto
// com a API do Supabase usando só a chave pública, como um atacante faria.
import { expect, test } from "@playwright/test";
import { clientePublico } from "./ajuda/admin";
import { SENHA } from "./ajuda/email";

async function logadoComo(email: string) {
  const cliente = clientePublico();
  const { error } = await cliente.auth.signInWithPassword({ email, password: SENHA });
  expect(error).toBeNull();
  return cliente;
}

test("sem login, nada de perfis nem de funções", async () => {
  const anonimo = clientePublico();
  const perfis = await anonimo.from("perfis").select("*");
  expect(perfis.error).not.toBeNull();
  expect(perfis.data).toBeNull();

  const decisao = await anonimo.rpc("decidir_cadastro", {
    p_perfil: "11111111-1111-1111-1111-111111111104",
    p_decisao: "aprovar",
    p_situacao_esperada: "pendente",
  });
  expect(decisao.error).not.toBeNull();

  const iniciais = await anonimo.from("administradores_iniciais").select("*");
  expect(iniciais.error).not.toBeNull();
});

test("membro só lê o próprio perfil e não decide, não promove e não apaga nada", async () => {
  const membro = await logadoComo("membro@teste.local");

  const { data } = await membro.from("perfis").select("email");
  expect(data).toEqual([{ email: "membro@teste.local" }]);

  const decisao = await membro.rpc("decidir_cadastro", {
    p_perfil: "11111111-1111-1111-1111-111111111104",
    p_decisao: "aprovar",
    p_situacao_esperada: "pendente",
  });
  expect(decisao.error?.message).toBe("sem_permissao");

  const promocao = await membro.rpc("alterar_papel", {
    p_perfil: "11111111-1111-1111-1111-111111111103",
    p_papel: "administrador",
    p_situacao_esperada: "aprovado",
  });
  expect(promocao.error?.message).toBe("sem_permissao");

  // Edição direta de campos protegidos é negada pelas permissões de coluna.
  const autopromocao = await membro.from("perfis").update({ papel: "administrador" }).eq("email", "membro@teste.local");
  expect(autopromocao.error).not.toBeNull();

  const exclusao = await membro.from("perfis").delete().eq("email", "lider@teste.local");
  expect(exclusao.error).not.toBeNull();
});

test("quem lidera um ministério não lê perfis alheios (a fila usa funções, não a tabela)", async () => {
  const lider = await logadoComo("lider@teste.local");
  const { data } = await lider.from("perfis").select("email, situacao");

  const alheios = (data ?? []).filter((p) => p.email !== "lider@teste.local");
  expect(alheios).toEqual([]);

  const gestao = await lider.rpc("alterar_situacao", {
    p_perfil: "11111111-1111-1111-1111-111111111103",
    p_nova: "acesso_removido",
    p_situacao_esperada: "aprovado",
  });
  expect(gestao.error?.message).toBe("sem_permissao");
});

test("recusado enxerga só o próprio perfil e não consegue se aprovar", async () => {
  const recusado = await logadoComo("recusado@teste.local");
  const { data } = await recusado.from("perfis").select("email");
  expect(data).toEqual([{ email: "recusado@teste.local" }]);

  const aprovar = await recusado.from("perfis").update({ situacao: "aprovado" }).eq("email", "recusado@teste.local");
  expect(aprovar.error).not.toBeNull();
});

// ===== Ministérios (funcionalidade 002, RF-035, CS-005) =====
const ID_LUCAS = "11111111-1111-1111-1111-111111111102";
const ID_MARTA = "11111111-1111-1111-1111-111111111103";
const ID_PAULO = "11111111-1111-1111-1111-111111111104"; // pendente, pediu o Louvor no seed
const LOUVOR = "22222222-2222-2222-2222-222222222201";
const RECEPCAO = "22222222-2222-2222-2222-222222222202";
const TEATRO = "22222222-2222-2222-2222-222222222203"; // desativado

test("visitante só lê nome e descrição de ministérios ativos, e nada mais", async () => {
  const anonimo = clientePublico();

  const publico = await anonimo.from("ministerios").select("id, nome, descricao, ativo");
  expect(publico.error).toBeNull();
  const ids = (publico.data ?? []).map((m) => m.id);
  expect(ids).toContain(LOUVOR);
  expect(ids).not.toContain(TEATRO); // desativado não aparece

  expect((await anonimo.from("ministerios").select("criado_em")).error).not.toBeNull();
  expect((await anonimo.from("participacoes_ministerio").select("*")).error).not.toBeNull();
  expect((await anonimo.from("pedidos_entrada_ministerio").select("*")).error).not.toBeNull();
  expect((await anonimo.rpc("listar_participantes", { p_ministerio: LOUVOR })).error).not.toBeNull();
  expect((await anonimo.rpc("criar_ministerio", { p_nome: "Invasor", p_descricao: "", p_lider: ID_LUCAS })).error).not.toBeNull();
});

test("membro não lê vínculos alheios, não escreve em ministérios e não decide pedidos", async () => {
  const membro = await logadoComo("membro@teste.local");

  // Só as próprias participações (a Marta participa do Louvor); a do Lucas não vem.
  const minhas = await membro.from("participacoes_ministerio").select("perfil_id");
  expect((minhas.data ?? []).every((p) => p.perfil_id === ID_MARTA)).toBe(true);
  expect((await membro.from("participacoes_ministerio").select("perfil_id").eq("perfil_id", ID_LUCAS)).data).toEqual([]);

  // Escritas diretas são negadas pelas permissões de tabela.
  expect((await membro.from("ministerios").insert({ nome: "Invasor", descricao: "" })).error).not.toBeNull();
  expect((await membro.from("ministerios").update({ nome: "Trocado" }).eq("id", LOUVOR)).error).not.toBeNull();
  expect((await membro.from("participacoes_ministerio").insert({ ministerio_id: RECEPCAO, perfil_id: ID_MARTA, papel: "lider" })).error).not.toBeNull();

  // Funções recusam quem não tem permissão.
  const criar = await membro.rpc("criar_ministerio", { p_nome: "Invasor", p_descricao: "", p_lider: ID_MARTA });
  expect(criar.error?.message).toBe("sem_permissao");
  const adicionar = await membro.rpc("adicionar_participante", { p_ministerio: LOUVOR, p_perfil: ID_MARTA, p_papel: "lider" });
  expect(adicionar.error?.message).toBe("sem_permissao");
  const buscar = await membro.rpc("buscar_pessoas", { p_ministerio: LOUVOR, p_termo: "lucas" });
  expect(buscar.error?.message).toBe("sem_permissao");

  // Lista de quem faz parte: a Marta participa do Louvor (vê); da Recepção, não (vazio).
  expect(((await membro.rpc("listar_participantes", { p_ministerio: LOUVOR })).data ?? []).length).toBeGreaterThan(0);
  expect((await membro.rpc("listar_participantes", { p_ministerio: RECEPCAO })).data).toEqual([]);
  expect((await membro.rpc("listar_pedidos_pendentes")).data).toEqual([]);
});

test("líder do Louvor não decide pedidos nem gerencia a Recepção", async () => {
  // Cria (como administrador do ambiente de teste) um pedido pendente para a Recepção.
  const { clienteAdmin } = await import("./ajuda/admin");
  const admin = clienteAdmin();
  const { data: pedido, error } = await admin
    .from("pedidos_entrada_ministerio")
    .insert({ ministerio_id: RECEPCAO, perfil_id: ID_PAULO })
    .select("id")
    .single();
  expect(error).toBeNull();

  const lider = await logadoComo("lider@teste.local");
  const decisao = await lider.rpc("decidir_pedido_entrada", { p_pedido: pedido!.id, p_decisao: "aceitar", p_situacao_esperada: "pendente" });
  expect(decisao.error?.message).toBe("sem_permissao");
  const adicionar = await lider.rpc("adicionar_participante", { p_ministerio: RECEPCAO, p_perfil: ID_MARTA, p_papel: "participante" });
  expect(adicionar.error?.message).toBe("sem_permissao");
  const edicao = await lider.rpc("editar_ministerio", { p_id: LOUVOR, p_nome: "Outro nome", p_descricao: "" });
  expect(edicao.error?.message).toBe("sem_permissao"); // nem o próprio ministério: só administrador edita
  expect((await lider.rpc("listar_participantes", { p_ministerio: RECEPCAO })).data).toEqual([]);

  // O líder só vê na fila os pedidos do Louvor, nunca o da Recepção.
  const fila = ((await lider.rpc("listar_pedidos_pendentes")).data ?? []) as { ministerio_id: string }[];
  expect(fila.every((p) => p.ministerio_id === LOUVOR)).toBe(true);

  await admin.from("pedidos_entrada_ministerio").delete().eq("id", pedido!.id); // limpa o que o teste criou
});

test("conta pendente (sem acesso aprovado) não gerencia ministérios nem decide pedidos", async () => {
  const pendente = await logadoComo("pendente@teste.local");
  const adicionar = await pendente.rpc("adicionar_participante", { p_ministerio: LOUVOR, p_perfil: ID_MARTA, p_papel: "lider" });
  expect(adicionar.error?.message).toBe("sem_permissao");
  const decisao = await pendente.rpc("decidir_pedido_entrada", {
    p_pedido: "00000000-0000-0000-0000-000000000000",
    p_decisao: "aceitar",
    p_situacao_esperada: "pendente",
  });
  expect(decisao.error?.message).toBe("sem_permissao");
  expect((await pendente.rpc("listar_participantes", { p_ministerio: LOUVOR })).data).toEqual([]);
  expect((await pendente.rpc("listar_pedidos_pendentes")).data).toEqual([]);
});

// ===== Escalas (funcionalidade 003, FR-025, SC-003) =====
const TABELAS_DE_ESCALAS = ["escalas", "vagas_escala", "respostas_escala", "pedidos_troca", "aptidoes"] as const;
const FUNCOES_DE_ESCRITA = [
  ["criar_funcao", { p_ministerio: LOUVOR, p_nome: "Invasora" }],
  ["criar_escala", { p_ministerio: LOUVOR, p_evento: "Invasão", p_data: "2099-01-01", p_horario: "09:00" }],
  ["publicar_escala", { p_escala: "99999999-9999-9999-9999-999999999999" }],
  ["cancelar_escala", { p_escala: "99999999-9999-9999-9999-999999999999" }],
  ["salvar_vaga", { p_escala: "99999999-9999-9999-9999-999999999999", p_vaga: null, p_funcao: LOUVOR, p_rotulo: "", p_perfil: null }],
  ["pedir_troca", { p_vaga: "99999999-9999-9999-9999-999999999999", p_indicada: ID_MARTA }],
  ["decidir_troca_lider", { p_pedido: "99999999-9999-9999-9999-999999999999", p_aprova: true }],
] as const;

test("visitante sem login não lê nem escreve nada de escalas", async () => {
  const anonimo = clientePublico();
  for (const tabela of TABELAS_DE_ESCALAS) {
    expect((await anonimo.from(tabela).select("*")).error, tabela).not.toBeNull();
  }
  expect((await anonimo.from("funcoes_ministerio").select("*")).error).not.toBeNull();
  for (const [nome, argumentos] of FUNCOES_DE_ESCRITA) {
    expect((await anonimo.rpc(nome, argumentos)).error, nome).not.toBeNull();
  }
  expect((await anonimo.rpc("ler_escala", { p_escala: "99999999-9999-9999-9999-999999999999" })).error).not.toBeNull();
  expect((await anonimo.rpc("minhas_escalas")).error).not.toBeNull();
});

test("membro não lê as tabelas de escalas direto e as funções de gestão o recusam", async () => {
  const membro = await logadoComo("membro@teste.local");

  // Leitura direta é negada: tudo passa por funções que escondem o que não é da pessoa.
  for (const tabela of TABELAS_DE_ESCALAS) {
    expect((await membro.from(tabela).select("*")).error, tabela).not.toBeNull();
  }
  // Escrita direta também.
  expect((await membro.from("escalas").insert({ ministerio_id: LOUVOR, evento: "Invasão", data: "2099-01-01", horario: "09:00" })).error).not.toBeNull();
  expect((await membro.from("funcoes_ministerio").insert({ ministerio_id: LOUVOR, nome: "Invasora" })).error).not.toBeNull();

  // Funções de gestão recusam quem não gere o ministério.
  expect((await membro.rpc("criar_funcao", { p_ministerio: LOUVOR, p_nome: "Invasora" })).error?.message).toBe("sem_permissao");
  expect(
    (await membro.rpc("criar_escala", { p_ministerio: LOUVOR, p_evento: "Invasão", p_data: "2099-01-01", p_horario: "09:00" })).error?.message,
  ).toBe("sem_permissao");

  // Escala inexistente ou de outro ministério: a mesma resposta (nada vaza).
  const escala = await membro.rpc("ler_escala", { p_escala: "99999999-9999-9999-9999-999999999999" });
  expect(escala.error).toBeNull();
  expect(escala.data).toBeNull();
  // Funções de escalas devolvem só nome, nunca email (a chave pública não vê emails de colegas).
  const candidatos = await membro.rpc("listar_candidatos_escala", { p_escala: "99999999-9999-9999-9999-999999999999" });
  expect(candidatos.data ?? []).toEqual([]);
});

test("o relógio das escalas não pode ser mudado por quem usa a API", async () => {
  const membro = await logadoComo("membro@teste.local");
  // `agora_sp` e `hoje_sp` são internas: ninguém as executa pela API.
  expect((await membro.rpc("agora_sp")).error).not.toBeNull();
  expect((await membro.rpc("hoje_sp")).error).not.toBeNull();
  // E uma configuração de sessão não é aceita pela API (não há como mudar "hoje").
  expect((await membro.rpc("set_config", { setting_name: "app.agora_teste", new_value: "2000-01-01", is_local: false })).error).not.toBeNull();
});
