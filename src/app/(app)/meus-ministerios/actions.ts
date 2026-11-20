"use server";
// Pedir entrada em ministério e cancelar o próprio pedido (RF-017). A regra de verdade está nas
// funções SQL `pedir_entrada_ministerio` e `cancelar_pedido_entrada`.
import { revalidatePath } from "next/cache";
import { criarClienteServidor } from "@/lib/supabase/server";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function atualizarTelas(ministerioId?: string) {
  revalidatePath("/meus-ministerios");
  revalidatePath("/ministerios");
  if (ministerioId) revalidatePath(`/ministerios/${ministerioId}`);
}

export async function pedirEntrada(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const id = String(formData.get("ministerio") ?? "");
  if (!UUID.test(id)) return { erro: "Ministério não encontrado." };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("pedir_entrada_ministerio", { p_ministerio: id });
  atualizarTelas(id);
  return error ? { erro: traduzirErro(error) } : {};
}

export async function cancelarPedido(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const pedido = String(formData.get("pedido") ?? "");
  const ministerio = String(formData.get("ministerio") ?? "");
  if (!UUID.test(pedido)) return { erro: "Pedido não encontrado." };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("cancelar_pedido_entrada", { p_pedido: pedido });
  atualizarTelas(UUID.test(ministerio) ? ministerio : undefined);
  return error ? { erro: traduzirErro(error) } : {};
}
