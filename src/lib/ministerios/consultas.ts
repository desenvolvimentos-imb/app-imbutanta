// Leituras de ministérios feitas no servidor. Quem pode ver o quê é decidido pelo BANCO (RLS):
// o administrador recebe todos os ministérios; as demais pessoas recebem só os ativos.
import { criarClienteServidor } from "@/lib/supabase/server";

export type Ministerio = {
  id: string;
  nome: string;
  descricao: string;
  ativo: boolean;
  desativado_em: string | null;
};

const COLUNAS = "id, nome, descricao, ativo, desativado_em";
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Erro com mensagem segura; o detalhe técnico vai só para o log do servidor. */
export class ErroConsulta extends Error {
  constructor() {
    super("Não foi possível carregar os dados agora.");
    this.name = "ErroConsulta";
  }
}

/**
 * Id da pessoa logada. As consultas "minhas" precisam filtrar por ele: a RLS do administrador libera
 * TODAS as linhas de participações e pedidos, então sem o filtro ele veria as de todo mundo.
 */
async function idDaPessoaLogada(supabase: Awaited<ReturnType<typeof criarClienteServidor>>): Promise<string | null> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user?.id ?? null;
}

function falhar(contexto: string, erro: { message: string }): never {
  console.error(`[ministerios] falha ao ${contexto}`, erro.message);
  throw new ErroConsulta();
}

export async function listarMinisterios(): Promise<Ministerio[]> {
  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.from("ministerios").select(COLUNAS).order("nome", { ascending: true });
  if (error) falhar("listar ministérios", error);
  return (data ?? []) as Ministerio[];
}

/** Ministérios ativos (nome e descrição): o que o cadastro e a tela de espera oferecem para marcar. */
export async function listarMinisteriosAtivos(): Promise<Ministerio[]> {
  const supabase = await criarClienteServidor();
  // O visitante (tela de cadastro) só tem permissão para ler estas colunas (migração 0003).
  const { data, error } = await supabase
    .from("ministerios")
    .select("id, nome, descricao, ativo")
    .eq("ativo", true)
    .order("nome", { ascending: true });
  if (error) falhar("listar ministérios ativos", error);
  return ((data ?? []) as Omit<Ministerio, "desativado_em">[]).map((m) => ({ ...m, desativado_em: null }));
}

/** Devolve o ministério, ou null se não existir ou a pessoa não puder vê-lo (ex.: desativado). */
export async function obterMinisterio(id: string): Promise<Ministerio | null> {
  if (!UUID.test(id)) return null; // evita erro do banco por endereço digitado errado
  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.from("ministerios").select(COLUNAS).eq("id", id).maybeSingle();
  if (error) falhar("ler o ministério", error);
  return (data as Ministerio | null) ?? null;
}

export type PessoaAprovada = { id: string; nome: string };

/** Contas aprovadas, para escolher o líder (só o administrador lê a lista; a RLS garante). */
export async function listarPessoasAprovadas(): Promise<PessoaAprovada[]> {
  const supabase = await criarClienteServidor();
  const { data, error } = await supabase
    .from("perfis")
    .select("id, nome")
    .eq("situacao", "aprovado")
    .order("nome", { ascending: true });
  if (error) falhar("listar pessoas aprovadas", error);
  return (data ?? []) as PessoaAprovada[];
}

export type Participante = { perfil_id: string; nome: string; papel: "participante" | "lider"; desde: string };

/**
 * Quem faz parte do ministério (nome e papel, nunca email). A função do banco devolve lista
 * vazia para quem não pode ver (RF-030, RF-031).
 */
export async function listarParticipantes(ministerioId: string): Promise<Participante[]> {
  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc("listar_participantes", { p_ministerio: ministerioId });
  if (error) falhar("listar participantes", error);
  return (data ?? []) as Participante[];
}

/** Busca pessoas (contas aprovadas que ainda não participam) pelo nome, para adicionar. */
export async function buscarPessoas(ministerioId: string, termo: string): Promise<PessoaAprovada[]> {
  if (termo.trim().length < 2) return [];
  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc("buscar_pessoas", { p_ministerio: ministerioId, p_termo: termo });
  if (error) falhar("buscar pessoas", error);
  return (data ?? []) as PessoaAprovada[];
}

/** Ids dos ministérios ativos que a pessoa logada lidera (liderança válida, lida do banco). */
export async function idsDosMinisteriosQueLidero(): Promise<string[]> {
  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc("ministerios_que_lidero");
  if (error) falhar("ler os ministérios que a pessoa lidera", error);
  return ((data ?? []) as { id: string }[]).map((m) => m.id);
}

export type PedidoDaPessoa = {
  id: string;
  situacao: "pendente" | "aceito" | "recusado" | "cancelado";
  criado_em: string;
  ministerio_id: string;
  ministerio_nome: string;
};

/** Pedidos de entrada da própria pessoa (filtrados por ela: a RLS do administrador libera todos). */
export async function listarMeusPedidos(): Promise<PedidoDaPessoa[]> {
  const supabase = await criarClienteServidor();
  const eu = await idDaPessoaLogada(supabase);
  if (!eu) return [];
  const { data, error } = await supabase
    .from("pedidos_entrada_ministerio")
    .select("id, situacao, criado_em, ministerio_id, ministerios(nome)")
    .eq("perfil_id", eu)
    .order("criado_em", { ascending: false });
  if (error) falhar("listar os pedidos da pessoa", error);

  type Linha = Omit<PedidoDaPessoa, "ministerio_nome"> & { ministerios: { nome: string } | { nome: string }[] | null };
  return ((data ?? []) as unknown as Linha[]).map((l) => {
    const m = Array.isArray(l.ministerios) ? l.ministerios[0] : l.ministerios;
    return { id: l.id, situacao: l.situacao, criado_em: l.criado_em, ministerio_id: l.ministerio_id, ministerio_nome: m?.nome ?? "Ministério desativado" };
  });
}

export type PedidoPendente = {
  pedido_id: string;
  ministerio_id: string;
  ministerio_nome: string;
  perfil_id: string;
  nome: string;
  criado_em: string;
  conta_pendente: boolean;
};

/**
 * Pedidos de entrada que a pessoa logada pode decidir: administrador, todos; líder, só os dos
 * ministérios que lidera. A função do banco devolve só nome (nunca email) (RF-028).
 */
export async function listarPedidosPendentes(): Promise<PedidoPendente[]> {
  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc("listar_pedidos_pendentes");
  if (error) falhar("listar pedidos pendentes", error);
  return (data ?? []) as PedidoPendente[];
}

export async function contarPedidosPendentes(): Promise<number> {
  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc("contar_pedidos_pendentes");
  if (error) falhar("contar pedidos pendentes", error);
  return Number(data ?? 0);
}

export type MinhaParticipacao = {
  ministerio_id: string;
  papel: "participante" | "lider";
  nome: string;
  descricao: string;
};

/** Ministérios ativos de que a pessoa participa (filtrados por ela: a RLS do administrador libera todos). */
export async function listarMinhasParticipacoes(): Promise<MinhaParticipacao[]> {
  const supabase = await criarClienteServidor();
  const eu = await idDaPessoaLogada(supabase);
  if (!eu) return [];
  const { data, error } = await supabase
    .from("participacoes_ministerio")
    .select("ministerio_id, papel, ministerios(nome, descricao, ativo)")
    .eq("perfil_id", eu);
  if (error) falhar("listar as participações da pessoa", error);

  type Linha = {
    ministerio_id: string;
    papel: "participante" | "lider";
    ministerios: { nome: string; descricao: string; ativo: boolean } | { nome: string; descricao: string; ativo: boolean }[] | null;
  };
  return ((data ?? []) as unknown as Linha[])
    .map((l) => ({ l, m: Array.isArray(l.ministerios) ? l.ministerios[0] : l.ministerios }))
    .filter(({ m }) => m?.ativo) // ministério desativado não aparece (continua só no histórico)
    .map(({ l, m }) => ({ ministerio_id: l.ministerio_id, papel: l.papel, nome: m!.nome, descricao: m!.descricao }))
    .sort((a, b) => a.nome.localeCompare(b.nome, "pt-BR"));
}

/**
 * Para cada ministério, só o pedido mais recente, e só se ainda interessa à pessoa: pendente
 * (aguardando) ou recusado (pode pedir de novo). Cancelados e aceitos não aparecem.
 */
export function pedidosRelevantes(pedidos: PedidoDaPessoa[]): PedidoDaPessoa[] {
  const maisRecente = new Map<string, PedidoDaPessoa>();
  for (const p of pedidos) {
    // `listarMeusPedidos` já vem do mais novo para o mais antigo.
    if (!maisRecente.has(p.ministerio_id)) maisRecente.set(p.ministerio_id, p);
  }
  return [...maisRecente.values()].filter((p) => p.situacao === "pendente" || p.situacao === "recusado");
}
