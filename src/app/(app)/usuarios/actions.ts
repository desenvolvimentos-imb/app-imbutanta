"use server";
// Gestão de usuários (RF-021). A regra de verdade está nas funções SQL `alterar_papel` e
// `alterar_situacao` (inclusive a proteção do último administrador); aqui só repassamos.
import { revalidatePath } from "next/cache";
import { criarClienteServidor } from "@/lib/supabase/server";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";

// Não existe papel global de líder: a liderança é uma participação em ministério (002).
const PAPEIS = ["membro", "administrador"];
const SITUACOES = ["pendente", "aprovado", "recusado", "acesso_removido"];

export async function alterarPapel(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const id = String(formData.get("id") ?? "");
  const papel = String(formData.get("papel") ?? "");
  if (!PAPEIS.includes(papel)) return { erro: "Papel inválido." };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("alterar_papel", {
    p_perfil: id,
    p_papel: papel,
    p_situacao_esperada: "aprovado",
  });

  revalidatePath("/usuarios");
  return error ? { erro: traduzirErro(error) } : {};
}

export async function alterarSituacao(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const id = String(formData.get("id") ?? "");
  const nova = String(formData.get("nova") ?? "");
  const esperada = String(formData.get("esperada") ?? "");
  if (!SITUACOES.includes(nova) || !SITUACOES.includes(esperada)) return { erro: "Situação inválida." };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("alterar_situacao", {
    p_perfil: id,
    p_nova: nova,
    p_situacao_esperada: esperada,
  });

  revalidatePath("/usuarios");
  return error ? { erro: traduzirErro(error) } : {};
}
