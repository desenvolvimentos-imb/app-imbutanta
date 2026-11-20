// Validação de dados de ministério (RF-006) e dos ministérios marcados no cadastro (RF-015).
// Mensagens em pt-BR. A regra final (tamanho, nome único) também está no banco.
import { z } from "zod";
import type { Resultado } from "@/lib/auth/validacao";

/** Um cadastro novo aceita no máximo esta quantidade de ministérios marcados (salvaguarda técnica). */
export const LIMITE_MINISTERIOS_NO_CADASTRO = 30;

const esquemaNome = z
  .string("Informe o nome do ministério.")
  .trim()
  .min(1, "Informe o nome do ministério.")
  .min(2, "O nome precisa ter pelo menos 2 letras.")
  .max(60, "O nome pode ter no máximo 60 caracteres.");

// A descrição é opcional: vazio ou ausente vira texto vazio.
const esquemaDescricao = z
  .string()
  .trim()
  .max(200, "A descrição pode ter no máximo 200 caracteres.");

function validar<T>(esquema: z.ZodType<T>, entrada: unknown): Resultado<T> {
  const r = esquema.safeParse(entrada);
  if (r.success) return { ok: true, valor: r.data };
  return { ok: false, mensagem: r.error.issues[0]?.message ?? "Dado inválido." };
}

export const validarNomeMinisterio = (nome: unknown) => validar(esquemaNome, nome);
export const validarDescricaoMinisterio = (descricao: unknown) =>
  validar(esquemaDescricao, descricao === null || descricao === undefined ? "" : descricao);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Filtra os ids de ministérios marcados no cadastro: mantém só UUIDs válidos, sem repetidos e
 * até o limite. Entrada ruim é IGNORADA em vez de dar erro: o cadastro nunca pode falhar por
 * causa dos ministérios (RF-015).
 */
export function validarIdsMinisterios(entrada: unknown): string[] {
  const lista = Array.isArray(entrada) ? entrada : entrada === undefined || entrada === null ? [] : [entrada];
  const vistos = new Set<string>();
  for (const item of lista) {
    if (typeof item !== "string" || !UUID.test(item)) continue;
    vistos.add(item.toLowerCase());
    if (vistos.size >= LIMITE_MINISTERIOS_NO_CADASTRO) break;
  }
  return [...vistos];
}
