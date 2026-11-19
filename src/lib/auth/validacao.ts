// Validação de dados de formulário (RF-003, RF-006). Mensagens em pt-BR.
// A mesma regra de senha existe em supabase/config.toml (a decisão final é do Supabase);
// aqui ela serve para dar uma resposta imediata e clara na tela.
import { z } from "zod";

export type Resultado<T> = { ok: true; valor: T } | { ok: false; mensagem: string };

const esquemaNome = z
  .string()
  .trim()
  .min(1, "Informe o seu nome.")
  .min(2, "O nome precisa ter pelo menos 2 letras.")
  .max(100, "O nome pode ter no máximo 100 caracteres.");

const esquemaEmail = z
  .string()
  .trim()
  .min(1, "Informe o seu email.")
  .toLowerCase()
  .pipe(z.email("Esse email não parece válido. Confira e tente de novo."));

// A senha não é aparada: espaços fazem parte dela.
const esquemaSenha = z
  .string()
  .min(8, "A senha precisa ter pelo menos 8 caracteres.")
  .refine((s) => /\p{L}/u.test(s), "A senha precisa ter letras e números.")
  .refine((s) => /\d/.test(s), "A senha precisa ter letras e números.");

function validar<T>(esquema: z.ZodType<T>, entrada: unknown): Resultado<T> {
  const r = esquema.safeParse(entrada);
  if (r.success) return { ok: true, valor: r.data };
  return { ok: false, mensagem: r.error.issues[0]?.message ?? "Dado inválido." };
}

export const validarNome = (nome: unknown) => validar(esquemaNome, nome);
export const validarEmail = (email: unknown) => validar(esquemaEmail, email);
export const validarSenha = (senha: unknown) => validar(esquemaSenha, senha);
