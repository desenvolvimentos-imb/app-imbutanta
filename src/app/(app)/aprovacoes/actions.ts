"use server";
// Aprovar ou recusar um cadastro (RF-012). A regra de verdade está na função SQL
// `decidir_cadastro`; aqui só repassamos a decisão e traduzimos o erro.
import { revalidatePath } from "next/cache";
import { criarClienteServidor } from "@/lib/supabase/server";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";

export async function decidirCadastro(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const id = String(formData.get("id") ?? "");
  const decisao = String(formData.get("decisao") ?? "");

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("decidir_cadastro", {
    p_perfil: id,
    p_decisao: decisao,
    // Informa a situação que o aprovador viu: se mudou, o banco avisa do conflito (RF-013).
    p_situacao_esperada: "pendente",
  });

  // Atualiza a lista nos dois casos (inclusive no conflito, para mostrar a situação real).
  revalidatePath("/aprovacoes");
  revalidatePath("/inicio");

  if (error) return { erro: traduzirErro(error) };
  return {};
}

// Aceitar ou recusar um PEDIDO de entrada em ministério (RF-019). A regra de verdade está na função
// SQL `decidir_pedido_entrada` (líder do ministério ou administrador; aceitar também ativa a
// conta de quem está pendente; recusar não mexe na conta).
export async function decidirPedido(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const id = String(formData.get("pedido") ?? "");
  const decisao = String(formData.get("decisao") ?? "");

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("decidir_pedido_entrada", {
    p_pedido: id,
    p_decisao: decisao,
    // Informa a situação que quem decide viu: se mudou, o banco avisa do conflito (RF-021).
    p_situacao_esperada: "pendente",
  });

  // Atualiza as telas nos dois casos (inclusive no conflito, para mostrar a situação real).
  revalidatePath("/aprovacoes");
  revalidatePath("/inicio");
  revalidatePath("/ministerios", "layout");

  return error ? { erro: traduzirErro(error) } : {};
}
