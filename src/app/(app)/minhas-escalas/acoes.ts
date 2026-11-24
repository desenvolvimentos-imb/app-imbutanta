"use server";
// Confirmar ou recusar a participação (FR-026, FR-027). A regra de verdade (escala publicada, antes
// do horário de início, pessoa escalada) está na função SQL; aqui validamos e traduzimos os erros.
import { revalidatePath } from "next/cache";
import { criarClienteServidor } from "@/lib/supabase/server";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { validarId, validarMotivo, validarResposta } from "@/lib/escalas/validacao";

export async function responderEscala(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const escala = validarId(formData.get("escala"));
  const resposta = validarResposta(formData.get("resposta"));
  const motivo = validarMotivo(formData.get("motivo"));
  if (!escala.ok || !resposta.ok) return { erro: "Escala não encontrada." };
  if (!motivo.ok) return { erros: { motivo: motivo.mensagem } };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("responder_escala", {
    p_escala: escala.valor,
    p_resposta: resposta.valor,
    p_motivo: motivo.valor,
  });

  // A resposta aparece em várias telas: lista da pessoa, detalhe da escala (para o líder) e início.
  revalidatePath("/minhas-escalas");
  revalidatePath("/inicio");
  const ministerio = validarId(formData.get("ministerio"));
  if (ministerio.ok) {
    revalidatePath(`/ministerios/${ministerio.valor}/escalas`);
    revalidatePath(`/ministerios/${ministerio.valor}/escalas/${escala.valor}`);
  }
  return error ? { erro: traduzirErro(error) } : {};
}
