"use server";
// Pedir o link de recuperação de senha (RF-027). A resposta é sempre a mesma, exista o
// email ou não (RF-007).
import { criarClienteServidor } from "@/lib/supabase/server";
import { validarEmail } from "@/lib/auth/validacao";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";

const RESPOSTA_NEUTRA =
  "Se o email estiver cadastrado, enviaremos um link para criar uma nova senha. Confira também a caixa de spam.";

export async function pedirRecuperacao(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const email = validarEmail(formData.get("email"));
  if (!email.ok) return { erros: { email: email.mensagem }, valores: { email: String(formData.get("email") ?? "") } };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.auth.resetPasswordForEmail(email.valor);

  // Só mostramos erro de limite de envios; qualquer outro vira a resposta neutra,
  // para não revelar se o email existe.
  if (error && (error.status === 429 || error.code?.startsWith("over_"))) {
    return { erro: traduzirErro(error), valores: { email: email.valor } };
  }
  return { info: RESPOSTA_NEUTRA };
}
