// Leituras de escalas feitas no servidor, SEMPRE por funções do banco (nunca pelas tabelas):
// as vagas mostram nomes e as respostas só podem ser vistas por quem de direito, e isso é decidido
// pelo banco (research.md, decisão 3). Aqui não há regra de negócio, só chamada e tipos.
// Toda leitura é dinâmica (sem cache de página), para o escalado sempre ver a versão atual (FR-016).
import { criarClienteServidor } from "@/lib/supabase/server";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Erro com mensagem segura; o detalhe técnico vai só para o log do servidor. */
export class ErroConsultaEscalas extends Error {
  constructor() {
    super("Não foi possível carregar os dados agora.");
    this.name = "ErroConsultaEscalas";
  }
}

export const idValido = (id: string) => UUID.test(id);

/** Chama uma função de leitura do banco e devolve o resultado tipado. */
async function chamar<T>(nome: string, argumentos: Record<string, unknown> = {}): Promise<T> {
  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc(nome, argumentos);
  if (error) {
    console.error(`[escalas] falha em ${nome}`, error.message);
    throw new ErroConsultaEscalas();
  }
  return data as T;
}

// ===== Funções e aptidões =====

export type FuncaoMinisterio = { id: string; nome: string; ativa: boolean };
export type AptidaoDaPessoa = { perfil_id: string; nome: string; funcao_id: string; tipo: "principal" | "secundaria" };
export type MinhaAptidao = { funcao_id: string; funcao: string; tipo: "principal" | "secundaria" };

export async function listarFuncoes(ministerioId: string, incluirInativas = false): Promise<FuncaoMinisterio[]> {
  if (!idValido(ministerioId)) return [];
  const r = await chamar<FuncaoMinisterio[] | null>("listar_funcoes", {
    p_ministerio: ministerioId,
    p_incluir_inativas: incluirInativas,
  });
  return r ?? [];
}

export async function listarAptidoes(ministerioId: string): Promise<AptidaoDaPessoa[]> {
  if (!idValido(ministerioId)) return [];
  return (await chamar<AptidaoDaPessoa[] | null>("listar_aptidoes", { p_ministerio: ministerioId })) ?? [];
}

export async function minhasAptidoes(ministerioId: string): Promise<MinhaAptidao[]> {
  if (!idValido(ministerioId)) return [];
  return (await chamar<MinhaAptidao[] | null>("minhas_aptidoes", { p_ministerio: ministerioId })) ?? [];
}

// ===== Escalas =====

export type SituacaoEscala = "rascunho" | "publicada" | "cancelada";
export type RespostaEscala = "pendente" | "confirmado" | "recusado";

export type EscalaResumo = {
  id: string;
  evento: string;
  data: string; // "AAAA-MM-DD"
  horario: string; // "HH:MM:SS"
  situacao: SituacaoEscala;
  total_vagas: number;
  vagas_abertas: number;
  /** Só o gestor recebe estas duas contagens (nulas para os demais). */
  recusadas: number | null;
  sem_resposta: number | null;
};

export type VagaDaEscala = {
  id: string;
  funcao_id: string;
  funcao: string;
  funcao_ativa: boolean;
  rotulo: string;
  ordem: number;
  pessoa: { id: string; nome: string } | null;
  em_aberto: boolean;
  minha: boolean;
  /** Só o gestor recebe os campos abaixo. */
  resposta?: RespostaEscala | null;
  motivo?: string | null;
  precisa_atencao?: "em_aberto" | "recusada" | "sem_resposta" | null;
};

export type EscalaDetalhe = {
  escala: {
    id: string;
    ministerio_id: string;
    ministerio: string;
    ministerio_ativo: boolean;
    evento: string;
    data: string;
    horario: string;
    observacao: string;
    situacao: SituacaoEscala;
  };
  papel: "gestor" | "participante";
  somente_leitura: boolean;
  iniciada: boolean;
  vagas: VagaDaEscala[];
  minhas_vagas: string[];
  minha_resposta: { resposta: RespostaEscala; motivo: string } | null;
  pode_responder: boolean;
  pode_pedir_troca: boolean;
  /** Só o gestor: uma linha por pessoa escalada. */
  respostas: { perfil_id: string; nome: string; resposta: RespostaEscala; motivo: string }[] | null;
};

export type Candidato = { id: string; nome: string; apta_para: string[] };

export async function listarEscalasMinisterio(ministerioId: string, passadas = false): Promise<EscalaResumo[]> {
  if (!idValido(ministerioId)) return [];
  return (await chamar<EscalaResumo[] | null>("listar_escalas_ministerio", { p_ministerio: ministerioId, p_passadas: passadas })) ?? [];
}

/** Devolve a escala, ou null se não existir ou a pessoa não puder vê-la (o banco decide). */
export async function lerEscala(escalaId: string): Promise<EscalaDetalhe | null> {
  if (!idValido(escalaId)) return null;
  return await chamar<EscalaDetalhe | null>("ler_escala", { p_escala: escalaId });
}

export async function listarCandidatos(escalaId: string): Promise<Candidato[]> {
  if (!idValido(escalaId)) return [];
  return (await chamar<Candidato[] | null>("listar_candidatos_escala", { p_escala: escalaId })) ?? [];
}

export async function contarEscalasComVagasAbertas(ministerioId: string): Promise<number> {
  if (!idValido(ministerioId)) return 0;
  return (await chamar<number | null>("contar_escalas_com_vagas_abertas", { p_ministerio: ministerioId })) ?? 0;
}

// ===== Minhas escalas =====

export type MinhaEscala = {
  escala_id: string;
  ministerio_id: string;
  ministerio: string;
  evento: string;
  funcoes: string[];
  data: string;
  horario: string;
  situacao: SituacaoEscala;
  minha_resposta: RespostaEscala;
  motivo: string;
  pode_responder: boolean;
};

export type Pendencias = { sem_resposta: number; trocas_recebidas: number; trocas_para_aprovar: number };

/** As escalas em que a pessoa está escalada: próximas (padrão) ou passadas. */
export async function minhasEscalas(passadas = false): Promise<MinhaEscala[]> {
  return (await chamar<MinhaEscala[] | null>("minhas_escalas", { p_passadas: passadas })) ?? [];
}

/** Números para a tela inicial (escalas sem resposta e, depois, pedidos de troca). */
export async function contarPendencias(): Promise<Pendencias> {
  const r = await chamar<Pendencias | null>("contar_pendencias_escala");
  return r ?? { sem_resposta: 0, trocas_recebidas: 0, trocas_para_aprovar: 0 };
}

// ===== Pedidos de troca =====

export type SituacaoTroca =
  | "aguardando_indicada" | "aguardando_lider" | "aprovado"
  | "recusado_indicada" | "recusado_lider" | "cancelado" | "sem_efeito";

export type PedidoTroca = {
  id: string;
  /** Como a pessoa aparece no pedido: quem pediu, a indicada ou quem gere o ministério. */
  papel_na_lista: "solicitante" | "indicada" | "gestor";
  /** Situação EFETIVA: pedido pendente de escala cancelada ou já iniciada vem como "sem_efeito". */
  situacao: SituacaoTroca;
  ministerio_id: string;
  ministerio: string;
  escala_id: string;
  evento: string;
  data: string;
  horario: string;
  vaga_id: string;
  funcao: string;
  rotulo: string;
  solicitante_id: string;
  solicitante: string;
  indicada_id: string;
  indicada: string;
  criado_em: string;
  pode_responder: boolean;
  pode_decidir: boolean;
  pode_cancelar: boolean;
};

export type PedidoDaEscala = {
  id: string;
  vaga_id: string;
  situacao: SituacaoTroca;
  solicitante_id: string;
  solicitante: string;
  indicada_id: string;
  indicada: string;
};

export type Candidata = { id: string; nome: string };

/** Pedidos que a pessoa fez e recebeu e, para quem gere ministérios, os que aguardam a aprovação. */
export async function listarPedidosTroca(): Promise<PedidoTroca[]> {
  return (await chamar<PedidoTroca[] | null>("listar_pedidos_troca")) ?? [];
}

/** Pedidos pendentes de uma escala que a pessoa pode ver (os próprios; o gestor vê todos). */
export async function listarPedidosDaEscala(escalaId: string): Promise<PedidoDaEscala[]> {
  if (!idValido(escalaId)) return [];
  return (await chamar<PedidoDaEscala[] | null>("listar_pedidos_da_escala", { p_escala: escalaId })) ?? [];
}

/** Participantes que podem ser indicadas para assumir a vaga. */
export async function listarCandidatasTroca(vagaId: string): Promise<Candidata[]> {
  if (!idValido(vagaId)) return [];
  return (await chamar<Candidata[] | null>("listar_candidatas_troca", { p_vaga: vagaId })) ?? [];
}
