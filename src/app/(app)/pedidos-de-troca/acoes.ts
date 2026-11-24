"use server";
// Pedidos de troca (FR-029 a FR-036). A regra de verdade está nas funções SQL (quem pode pedir,
// aceitar, aprovar, cancelar; escala publicada e não iniciada; troca atômica); aqui validamos o
// formato e traduzimos os erros.
import { revalidatePath } from "next/cache";
import { criarClienteServidor } from "@/lib/supabase/server";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { lerAvisos } from "@/lib/escalas/avisos";
import type { EstadoVaga } from "@/lib/escalas/estado";
import { validarId } from "@/lib/escalas/validacao";

function atualizar(formData: FormData) {
  revalidatePath("/pedidos-de-troca");
  revalidatePath("/minhas-escalas");
  revalidatePath("/inicio");
  const ministerio = validarId(formData.get("ministerio"));
  const escala = validarId(formData.get("escala"));
  if (ministerio.ok) {
    revalidatePath(`/ministerios/${ministerio.valor}/escalas`);
    if (escala.ok) revalidatePath(`/ministerios/${ministerio.valor}/escalas/${escala.valor}`);
  }
}

export async function pedirTroca(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const vaga = validarId(formData.get("vaga"));
  const indicada = validarId(formData.get("indicada"));
  if (!vaga.ok) return { erro: "Vaga não encontrada." };
  if (!indicada.ok) return { erros: { indicada: "Escolha a pessoa que vai assumir a vaga." } };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("pedir_troca", { p_vaga: vaga.valor, p_indicada: indicada.valor });
  atualizar(formData);
  return error ? { erro: traduzirErro(error) } : { info: "Pedido enviado. Se ela aceitar, o líder decide." };
}

export async function responderPedidoTroca(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const pedido = validarId(formData.get("pedido"));
  const aceita = formData.get("aceita");
  if (!pedido.ok || (aceita !== "1" && aceita !== "0")) return { erro: "Pedido não encontrado." };

  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc("responder_pedido_troca", { p_pedido: pedido.valor, p_aceita: aceita === "1" });
  atualizar(formData);
  if (error) return { erro: traduzirErro(error) };
  // O pedido pode ter perdido efeito no meio do caminho (a indicada já foi escalada por outro caminho).
  if ((data as { situacao?: string } | null)?.situacao === "sem_efeito") {
    return { erro: "Este pedido perdeu efeito porque a escala mudou." };
  }
  return {};
}

/**
 * O líder aprova ou recusa. Ao aprovar, o banco devolve avisos (falta de aptidão da indicada, outro
 * ministério no mesmo dia) e só decide quando o líder confirma que está ciente.
 */
export async function decidirTroca(_anterior: EstadoVaga, formData: FormData): Promise<EstadoVaga> {
  const pedido = validarId(formData.get("pedido"));
  const aprova = formData.get("aprova");
  if (!pedido.ok || (aprova !== "1" && aprova !== "0")) return { erro: "Pedido não encontrado." };

  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc("decidir_troca_lider", {
    p_pedido: pedido.valor,
    p_aprova: aprova === "1",
    p_ciente: formData.get("ciente") === "1",
  });
  atualizar(formData);
  if (error) return { erro: traduzirErro(error) };
  const resultado = data as { decidido: boolean; avisos?: unknown };
  if (!resultado.decidido) return { avisos: lerAvisos(resultado.avisos) };
  return {};
}

export async function cancelarPedidoTroca(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const pedido = validarId(formData.get("pedido"));
  if (!pedido.ok) return { erro: "Pedido não encontrado." };
  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("cancelar_pedido_troca", { p_pedido: pedido.valor });
  atualizar(formData);
  return error ? { erro: traduzirErro(error) } : {};
}
