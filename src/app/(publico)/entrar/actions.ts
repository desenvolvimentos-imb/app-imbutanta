"use server";
// Entrar com email e senha (RF-002). Mensagem de erro sempre genérica (RF-007).
import { redirect } from "next/navigation";
import { criarClienteServidor } from "@/lib/supabase/server";
import { destinoPosLogin } from "@/lib/auth/destino-pos-login";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";

export async function entrar(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  const senha = String(formData.get("senha") ?? "");
  const voltar = String(formData.get("voltar") ?? "");

  if (!email || !senha) {
    return { erro: "Informe o email e a senha.", valores: { email } };
  }

  const supabase = await criarClienteServidor();
  const { error } = await supabase.auth.signInWithPassword({ email, password: senha });
  if (error) return { erro: traduzirErro(error), valores: { email } };

  // redirect() lança uma exceção interna do Next; por isso fica fora de try/catch.
  redirect(await destinoPosLogin(supabase, voltar));
}
