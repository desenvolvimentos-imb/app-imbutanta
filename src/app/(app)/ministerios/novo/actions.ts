"use server";
// Criar ministério (RF-001). A regra de verdade está na função SQL `criar_ministerio`
// (só administrador, nome único, líder inicial); aqui validamos o formato e repassamos.
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { criarClienteServidor } from "@/lib/supabase/server";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { validarDescricaoMinisterio, validarNomeMinisterio } from "@/lib/ministerios/validacao";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function criarMinisterio(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const nome = validarNomeMinisterio(formData.get("nome"));
  const descricao = validarDescricaoMinisterio(formData.get("descricao"));
  const lider = String(formData.get("lider") ?? "");

  const valores = {
    nome: String(formData.get("nome") ?? ""),
    descricao: String(formData.get("descricao") ?? ""),
    lider,
  };

  const erros: Record<string, string> = {};
  if (!nome.ok) erros.nome = nome.mensagem;
  if (!descricao.ok) erros.descricao = descricao.mensagem;
  if (!UUID.test(lider)) erros.lider = "Escolha o líder inicial.";
  if (Object.keys(erros).length > 0 || !nome.ok || !descricao.ok) return { erros, valores };

  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc("criar_ministerio", {
    p_nome: nome.valor,
    p_descricao: descricao.valor,
    p_lider: lider,
  });
  if (error) return { erro: traduzirErro(error), valores };

  revalidatePath("/ministerios");
  const criado = data as { id: string };
  redirect(`/ministerios/${criado.id}`); // fora de try/catch: redirect funciona levantando uma exceção
}
