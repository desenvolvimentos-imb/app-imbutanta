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
