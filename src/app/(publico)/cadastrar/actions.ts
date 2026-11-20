"use server";
// Cadastro por email e senha (RF-002, RF-003, RF-006). O Supabase envia o email de
// confirmação; enquanto não confirmar, a pessoa não aparece na fila de aprovação.
import { criarClienteServidor } from "@/lib/supabase/server";
import { validarEmail, validarNome, validarSenha } from "@/lib/auth/validacao";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { validarIdsMinisterios } from "@/lib/ministerios/validacao";

// Mesma resposta para email novo e para email que já tem conta: assim ninguém descobre,
// pelo cadastro, quais emails estão cadastrados (RF-007).
const MENSAGEM_ENVIADO =
  "Se este email ainda não tem conta, enviamos um link de confirmação para ele. Abra-o para concluir o cadastro e depois aguarde a aprovação. Se já tem conta, é só entrar (ou recuperar a senha).";

const JA_EXISTE = ["user_already_exists", "email_exists"];

export async function cadastrar(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const nome = validarNome(formData.get("nome"));
  const email = validarEmail(formData.get("email"));
  const senha = validarSenha(formData.get("senha"));

  const valores = {
    nome: String(formData.get("nome") ?? ""),
    email: String(formData.get("email") ?? ""),
  };

  const erros: Record<string, string> = {};
  if (!nome.ok) erros.nome = nome.mensagem;
  if (!email.ok) erros.email = email.mensagem;
  if (!senha.ok) erros.senha = senha.mensagem;
  if (!nome.ok || !email.ok || !senha.ok) return { erros, valores };

  // Ministérios marcados: viram PEDIDOS pelo gatilho do banco. Entrada ruim é ignorada: o
  // cadastro nunca falha por causa dos ministérios.
  const ministerios = validarIdsMinisterios(formData.getAll("ministerios"));

  const supabase = await criarClienteServidor();
  const { error } = await supabase.auth.signUp({
    email: email.valor,
    password: senha.valor,
    options: { data: { nome: nome.valor, ...(ministerios.length > 0 ? { ministerios } : {}) } },
  });

  if (error && !JA_EXISTE.includes(error.code ?? "")) {
    return { erro: traduzirErro(error), valores };
  }
  return { info: MENSAGEM_ENVIADO };
}
