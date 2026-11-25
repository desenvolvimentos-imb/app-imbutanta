// Leituras de disponibilidade feitas no servidor, SEMPRE por funções do banco (nunca pelas
// tabelas): a grade mostra nomes e as respostas alheias só podem ser vistas por líderes e
// administradores, e isso é decidido pelo banco (research.md, decisão 4). Aqui não há regra de
// negócio, só chamada e tipos. Toda leitura é dinâmica (sem cache de página).
import { criarClienteServidor } from "@/lib/supabase/server";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Erro com mensagem segura; o detalhe técnico vai só para o log do servidor. */
export class ErroConsultaDisponibilidade extends Error {
  constructor() {
    super("Não foi possível carregar os dados agora.");
    this.name = "ErroConsultaDisponibilidade";
  }
}

export const idValido = (id: string) => UUID.test(id);

async function chamar<T>(nome: string, argumentos: Record<string, unknown> = {}): Promise<T> {
  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc(nome, argumentos);
  if (error) {
    console.error(`[disponibilidade] falha em ${nome}`, error.message);
    throw new ErroConsultaDisponibilidade();
  }
  return data as T;
}

export type RespostaDisponibilidade = "disponivel" | "indisponivel";
/** Na escala, "sem resposta" também é uma situação (a ausência de linha no banco). */
export type SituacaoNaData = RespostaDisponibilidade | "sem_resposta";
export type MotivoFechada = "lider" | "prazo" | "ministerio_desativado" | null;

// ===== Lista do ministério (gestor) =====

export type ResumoConsulta = {
  id: string;
  titulo: string;
  prazo: string | null;
  aberta: boolean;
  motivo_fechada: MotivoFechada;
  total_datas: number;
  /** Participantes ativos que ainda não marcaram nenhuma data. */
  sem_resposta_nenhuma: number;
  primeira_data: string | null;
};

export async function listarConsultasMinisterio(ministerioId: string): Promise<ResumoConsulta[]> {
  if (!idValido(ministerioId)) return [];
  return (await chamar<ResumoConsulta[] | null>("listar_consultas_ministerio", { p_ministerio: ministerioId })) ?? [];
}

// ===== Visão do participante =====

export type DataParaResponder = {
  id: string;
  data: string;
  rotulo: string;
  passada: boolean;
  resposta: RespostaDisponibilidade | null;
};

export type ConsultaParaResponder = {
  id: string;
  ministerio_id: string;
  ministerio: string;
  titulo: string;
  mensagem: string;
  prazo: string | null;
  aberta: boolean;
  motivo_fechada: MotivoFechada;
  pode_responder: boolean;
  datas: DataParaResponder[];
  observacao: string;
  sem_resposta: number;
};

export type MinhasConsultas = {
  abertas: ConsultaParaResponder[];
  fechadas_recentes: ConsultaParaResponder[];
};

export async function minhasConsultas(): Promise<MinhasConsultas> {
  const r = await chamar<MinhasConsultas | null>("minhas_consultas");
  return r ?? { abertas: [], fechadas_recentes: [] };
}

export async function lerConsultaParticipante(consultaId: string): Promise<ConsultaParaResponder | null> {
  if (!idValido(consultaId)) return null;
  return await chamar<ConsultaParaResponder | null>("ler_consulta_participante", { p_consulta: consultaId });
}

export async function contarConsultasPendentes(): Promise<number> {
  return (await chamar<number | null>("contar_consultas_pendentes")) ?? 0;
}

// ===== Grade do líder =====

export type PorFuncao = { funcao_id: string; funcao: string; disponiveis: number; faltando: boolean };

export type DataDaGrade = {
  id: string;
  data: string;
  rotulo: string;
  passada: boolean;
  disponiveis: number;
  indisponiveis: number;
  sem_resposta: number;
  por_funcao: PorFuncao[];
};

export type CelulaDaGrade = { resposta: RespostaDisponibilidade; preenchida_pelo_lider: boolean };

export type LinhaDaGrade = {
  perfil_id: string;
  nome: string;
  nao_respondeu: boolean;
  observacao: string;
  /** Só as datas marcadas; as ausentes estão "sem resposta". */
  respostas: Record<string, CelulaDaGrade>;
};

export type GradeConsulta = {
  consulta: {
    id: string;
    ministerio_id: string;
    ministerio: string;
    ministerio_ativo: boolean;
    titulo: string;
    mensagem: string;
    prazo: string | null;
    aberta: boolean;
    motivo_fechada: MotivoFechada;
  };
  datas: DataDaGrade[];
  participantes: LinhaDaGrade[];
  tem_funcoes: boolean;
};

export async function lerConsultaGestor(consultaId: string): Promise<GradeConsulta | null> {
  if (!idValido(consultaId)) return null;
  return await chamar<GradeConsulta | null>("ler_consulta_gestor", { p_consulta: consultaId });
}

// ===== Integração com escalas =====

export type DisponibilidadeNaEscala = { perfil_id: string; resposta: SituacaoNaData };

/** Resposta de cada participante na data da escala; vazio quando a data não está em consulta. */
export async function disponibilidadeDaEscala(escalaId: string): Promise<Map<string, SituacaoNaData>> {
  if (!idValido(escalaId)) return new Map();
  const linhas = (await chamar<DisponibilidadeNaEscala[] | null>("disponibilidade_da_escala", { p_escala: escalaId })) ?? [];
  return new Map(linhas.map((l) => [l.perfil_id, l.resposta]));
}
