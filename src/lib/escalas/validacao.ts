// Validação dos dados de escalas, funções e respostas (FR-005, FR-008, FR-026, FR-001/FR-004).
// Mensagens em pt-BR. A regra final (tamanhos, datas) também está no banco.
import { z } from "zod";
import type { Resultado } from "@/lib/auth/validacao";
import { dataValida } from "./datas";

export const MAX_VAGAS_POR_ESCALA = 50;

function validar<T>(esquema: z.ZodType<T>, entrada: unknown): Resultado<T> {
  const r = esquema.safeParse(entrada);
  if (r.success) return { ok: true, valor: r.data };
  return { ok: false, mensagem: r.error.issues[0]?.message ?? "Dado inválido." };
}

// Campo opcional: ausente ou nulo vira texto vazio.
const vazioSeAusente = (v: unknown) => (v === null || v === undefined ? "" : v);

const esquemaEvento = z
  .string("Informe o nome do evento.")
  .trim()
  .min(1, "Informe o nome do evento.")
  .min(2, "O nome do evento precisa ter pelo menos 2 letras.")
  .max(80, "O nome do evento pode ter no máximo 80 caracteres.");

const esquemaObservacao = z.string().trim().max(300, "A observação pode ter no máximo 300 caracteres.");
const esquemaRotulo = z.string().trim().max(40, "O rótulo da vaga pode ter no máximo 40 caracteres.");
const esquemaMotivo = z.string().trim().max(200, "O motivo pode ter no máximo 200 caracteres.");

const esquemaNomeFuncao = z
  .string("Informe o nome da função.")
  .trim()
  .min(1, "Informe o nome da função.")
  .min(2, "O nome da função precisa ter pelo menos 2 letras.")
  .max(40, "O nome da função pode ter no máximo 40 caracteres.");

const esquemaData = z
  .string("Informe a data.")
  .trim()
  .min(1, "Informe a data.")
  .refine(dataValida, "Informe uma data válida.");

// Aceita "HH:MM" (campo de horário do navegador) e "HH:MM:SS" (vindo do banco).
const esquemaHorario = z
  .string("Informe o horário de início.")
  .trim()
  .min(1, "Informe o horário de início.")
  .regex(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/, "Informe um horário válido.")
  .transform((h) => h.slice(0, 5));

const esquemaTipoAptidao = z.enum(["principal", "secundaria"], "Escolha se a função é principal ou secundária.");
const esquemaResposta = z.enum(["confirmado", "recusado"], "Escolha confirmar ou recusar.");

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const esquemaId = z.string("Identificador inválido.").regex(UUID, "Identificador inválido.");

export const validarEvento = (v: unknown) => validar(esquemaEvento, v);
export const validarObservacao = (v: unknown) => validar(esquemaObservacao, vazioSeAusente(v));
export const validarRotulo = (v: unknown) => validar(esquemaRotulo, vazioSeAusente(v));
export const validarMotivo = (v: unknown) => validar(esquemaMotivo, vazioSeAusente(v));
export const validarNomeFuncao = (v: unknown) => validar(esquemaNomeFuncao, v);
export const validarData = (v: unknown) => validar(esquemaData, v);
export const validarHorario = (v: unknown) => validar(esquemaHorario, v);
export const validarTipoAptidao = (v: unknown) => validar(esquemaTipoAptidao, v);
export const validarResposta = (v: unknown) => validar(esquemaResposta, v);
export const validarId = (v: unknown) => validar(esquemaId, v);

export type DadosEscala = { evento: string; data: string; horario: string; observacao: string };

/** Valida os campos de uma escala de uma vez; devolve a primeira mensagem de erro. */
export function validarEscala(entrada: { evento: unknown; data: unknown; horario: unknown; observacao?: unknown }): Resultado<DadosEscala> {
  const evento = validarEvento(entrada.evento);
  if (!evento.ok) return evento;
  const data = validarData(entrada.data);
  if (!data.ok) return data;
  const horario = validarHorario(entrada.horario);
  if (!horario.ok) return horario;
  const observacao = validarObservacao(entrada.observacao);
  if (!observacao.ok) return observacao;
  return { ok: true, valor: { evento: evento.valor, data: data.valor, horario: horario.valor, observacao: observacao.valor } };
}
