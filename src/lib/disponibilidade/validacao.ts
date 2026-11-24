// Validação dos dados de consultas de disponibilidade e respostas (RF-001, RF-003, RF-004, RF-016,
// RF-018). Mensagens em pt-BR. A regra final (tamanhos, datas, unicidade) também está no banco.
import { z } from "zod";
import type { Resultado } from "@/lib/auth/validacao";
import { dataValida } from "@/lib/escalas/datas";

export const MAX_DATAS_POR_CONSULTA = 31;
export const MAX_OBSERVACAO = 300;

function validar<T>(esquema: z.ZodType<T>, entrada: unknown): Resultado<T> {
  const r = esquema.safeParse(entrada);
  if (r.success) return { ok: true, valor: r.data };
  return { ok: false, mensagem: r.error.issues[0]?.message ?? "Dado inválido." };
}

// Campo opcional: ausente ou nulo vira texto vazio.
const vazioSeAusente = (v: unknown) => (v === null || v === undefined ? "" : v);

const esquemaTitulo = z
  .string("Informe o título da consulta.")
  .trim()
  .min(1, "Informe o título da consulta.")
  .min(2, "O título precisa ter pelo menos 2 letras.")
  .max(80, "O título pode ter no máximo 80 caracteres.");
const esquemaMensagem = z.string().trim().max(500, "A mensagem pode ter no máximo 500 caracteres.");
const esquemaRotulo = z.string().trim().max(40, "O rótulo da data pode ter no máximo 40 caracteres.");
const esquemaObservacao = z
  .string()
  .trim()
  .max(MAX_OBSERVACAO, `A observação pode ter no máximo ${MAX_OBSERVACAO} caracteres.`);
const esquemaDataConsulta = z
  .string("Informe a data.")
  .trim()
  .min(1, "Informe a data.")
  .refine(dataValida, "Informe uma data válida.");
// Prazo é opcional: vazio ou ausente significa "sem prazo".
const esquemaPrazo = z
  .string()
  .trim()
  .refine((v) => v === "" || dataValida(v), "Informe um prazo válido.")
  .transform((v) => (v === "" ? null : v));
const esquemaResposta = z.enum(["disponivel", "indisponivel"], "Escolha disponível ou indisponível.").nullable();

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const esquemaId = z.string("Identificador inválido.").regex(UUID, "Identificador inválido.");

export const validarTitulo = (v: unknown) => validar(esquemaTitulo, v);
export const validarMensagem = (v: unknown) => validar(esquemaMensagem, vazioSeAusente(v));
export const validarRotuloData = (v: unknown) => validar(esquemaRotulo, vazioSeAusente(v));
export const validarObservacao = (v: unknown) => validar(esquemaObservacao, vazioSeAusente(v));
export const validarDataConsulta = (v: unknown) => validar(esquemaDataConsulta, v);
export const validarPrazo = (v: unknown) => validar(esquemaPrazo, vazioSeAusente(v));
export const validarRespostaDisponibilidade = (v: unknown) => validar(esquemaResposta, v ?? null);
export const validarId = (v: unknown) => validar(esquemaId, v);

export type DataDaConsulta = { data: string; rotulo: string };

/** Valida a lista de datas: ao menos uma, no máximo 31, sem repetição, cada uma real e com rótulo curto. */
export function validarDatas(entrada: unknown): Resultado<DataDaConsulta[]> {
  if (!Array.isArray(entrada) || entrada.length === 0) {
    return { ok: false, mensagem: "A consulta precisa ter pelo menos uma data." };
  }
  if (entrada.length > MAX_DATAS_POR_CONSULTA) {
    return { ok: false, mensagem: `Uma consulta pode ter no máximo ${MAX_DATAS_POR_CONSULTA} datas.` };
  }
  const vistas = new Set<string>();
  const datas: DataDaConsulta[] = [];
  for (const item of entrada) {
    const bruto = (item ?? {}) as { data?: unknown; rotulo?: unknown };
    const data = validarDataConsulta(bruto.data);
    if (!data.ok) return data;
    if (vistas.has(data.valor)) return { ok: false, mensagem: "Há datas repetidas na lista." };
    vistas.add(data.valor);
    const rotulo = validarRotuloData(bruto.rotulo);
    if (!rotulo.ok) return rotulo;
    datas.push({ data: data.valor, rotulo: rotulo.valor });
  }
  datas.sort((a, b) => a.data.localeCompare(b.data));
  return { ok: true, valor: datas };
}

export type DadosConsulta = { titulo: string; mensagem: string; prazo: string | null };

/** Valida título, mensagem e prazo de uma vez; devolve a primeira mensagem de erro. */
export function validarConsulta(entrada: { titulo: unknown; mensagem?: unknown; prazo?: unknown }): Resultado<DadosConsulta> {
  const titulo = validarTitulo(entrada.titulo);
  if (!titulo.ok) return titulo;
  const mensagem = validarMensagem(entrada.mensagem);
  if (!mensagem.ok) return mensagem;
  const prazo = validarPrazo(entrada.prazo);
  if (!prazo.ok) return prazo;
  return { ok: true, valor: { titulo: titulo.valor, mensagem: mensagem.valor, prazo: prazo.valor } };
}

export type RespostaDaData = { data_id: string; resposta: "disponivel" | "indisponivel" | null };

/** Valida a lista de respostas enviada pela tela (resposta nula = voltar a "sem resposta"). */
export function validarRespostas(entrada: unknown): Resultado<RespostaDaData[]> {
  if (!Array.isArray(entrada)) return { ok: false, mensagem: "Resposta inválida. Atualize a tela e tente de novo." };
  const respostas: RespostaDaData[] = [];
  for (const item of entrada) {
    const bruto = (item ?? {}) as { data_id?: unknown; resposta?: unknown };
    const id = validarId(bruto.data_id);
    if (!id.ok) return id;
    const resposta = validarRespostaDisponibilidade(bruto.resposta);
    if (!resposta.ok) return resposta;
    respostas.push({ data_id: id.valor, resposta: resposta.valor });
  }
  return { ok: true, valor: respostas };
}
