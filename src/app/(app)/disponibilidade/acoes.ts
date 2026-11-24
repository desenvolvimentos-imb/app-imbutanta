"use server";
// A própria pessoa responde à consulta (RF-014 a RF-018). Salva em uma única chamada, tudo ou nada.
import { revalidatePath } from "next/cache";
import { criarClienteServidor } from "@/lib/supabase/server";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { validarId, validarObservacao, validarRespostas } from "@/lib/disponibilidade/validacao";

export async function salvarRespostas(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const consulta = validarId(formData.get("consulta"));
  if (!consulta.ok) return { erro: "Consulta não encontrada." };

  // Só as datas que ainda aceitam resposta vêm em `datas_ids`; cada uma tem um grupo de opções.
  const ids = formData.getAll("datas_ids").map(String);
  const respostas = validarRespostas(
    ids.map((id) => ({ data_id: id, resposta: String(formData.get(`resp_${id}`) ?? "") || null })),
  );
  if (!respostas.ok) return { erro: respostas.mensagem };
  const observacao = validarObservacao(formData.get("observacao"));
  if (!observacao.ok) return { erro: observacao.mensagem, erros: { observacao: observacao.mensagem } };

  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc("responder_disponibilidade", {
    p_consulta: consulta.valor,
    p_respostas: respostas.valor,
    p_observacao: observacao.valor,
  });
  revalidatePath("/disponibilidade");
  revalidatePath(`/disponibilidade/${consulta.valor}`);
  revalidatePath("/inicio");
  if (error) return { erro: traduzirErro(error) };

  const faltam = (data as { sem_resposta?: number } | null)?.sem_resposta ?? 0;
  return {
    info: faltam === 0 ? "Respostas salvas. Tudo respondido." : `Respostas salvas. ${faltam === 1 ? "Falta 1 data" : `Faltam ${faltam} datas`}.`,
  };
}
