"use server";
// Definir a nova senha depois de abrir o link de recuperação (RF-027).
import { redirect } from "next/navigation";
import { criarClienteServidor } from "@/lib/supabase/server";
import { validarSenha } from "@/lib/auth/validacao";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";

export async function redefinirSenha(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const senha = validarSenha(formData.get("senha"));
  const confirmacao = String(formData.get("confirmacao") ?? "");

  if (!senha.ok) return { erros: { senha: senha.mensagem } };
  if (senha.valor !== confirmacao) return { erros: { confirmacao: "As senhas não são iguais." } };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.auth.updateUser({ password: senha.valor });
  if (error) return { erro: traduzirErro(error) };

  // Encerra a sessão aberta pelo link: a pessoa entra de novo, já com a nova senha.
  await supabase.auth.signOut();
  redirect("/entrar?ok=senha");
}
