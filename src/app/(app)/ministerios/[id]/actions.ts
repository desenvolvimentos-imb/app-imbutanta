"use server";
// Editar, desativar e reativar ministério (RF-002 a RF-004). A regra de verdade está nas funções
// SQL (só administrador, nome único, líder válido); aqui validamos o formato e repassamos.
import { revalidatePath } from "next/cache";
import { criarClienteServidor } from "@/lib/supabase/server";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { validarDescricaoMinisterio, validarNomeMinisterio } from "@/lib/ministerios/validacao";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function atualizarTelas(id: string) {
  revalidatePath("/ministerios");
  revalidatePath(`/ministerios/${id}`);
}

export async function editarMinisterio(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const id = String(formData.get("id") ?? "");
  const nome = validarNomeMinisterio(formData.get("nome"));
  const descricao = validarDescricaoMinisterio(formData.get("descricao"));
  const valores = { nome: String(formData.get("nome") ?? ""), descricao: String(formData.get("descricao") ?? "") };

  if (!UUID.test(id)) return { erro: "Ministério não encontrado.", valores };
  const erros: Record<string, string> = {};
  if (!nome.ok) erros.nome = nome.mensagem;
  if (!descricao.ok) erros.descricao = descricao.mensagem;
  if (!nome.ok || !descricao.ok) return { erros, valores };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("editar_ministerio", {
    p_id: id,
    p_nome: nome.valor,
    p_descricao: descricao.valor,
  });
  atualizarTelas(id);
  if (error) return { erro: traduzirErro(error), valores };
  return { info: "Alterações salvas." };
}

export async function desativarMinisterio(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const id = String(formData.get("id") ?? "");
  if (!UUID.test(id)) return { erro: "Ministério não encontrado." };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("desativar_ministerio", { p_id: id });
  atualizarTelas(id);
  return error ? { erro: traduzirErro(error) } : {};
}

export async function reativarMinisterio(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const id = String(formData.get("id") ?? "");
  const lider = String(formData.get("lider") ?? "");
  if (!UUID.test(id)) return { erro: "Ministério não encontrado." };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("reativar_ministerio", {
    p_id: id,
    p_lider: UUID.test(lider) ? lider : null,
  });
  atualizarTelas(id);
  return error ? { erro: traduzirErro(error) } : {};
}

// ---- Participantes (RF-011) ----
// Quem pode gerir é decidido pelo banco (administrador ou líder DESTE ministério).

const PAPEIS = ["participante", "lider"];

export async function adicionarParticipante(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const id = String(formData.get("id") ?? "");
  const pessoa = String(formData.get("pessoa") ?? "");
  if (!UUID.test(id) || !UUID.test(pessoa)) return { erro: "Pessoa ou ministério não encontrado." };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("adicionar_participante", {
    p_ministerio: id,
    p_perfil: pessoa,
    p_papel: "participante",
  });
  atualizarTelas(id);
  return error ? { erro: traduzirErro(error) } : {};
}

export async function alterarPapelNoMinisterio(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const id = String(formData.get("id") ?? "");
  const pessoa = String(formData.get("pessoa") ?? "");
  const papel = String(formData.get("papel") ?? "");
  if (!UUID.test(id) || !UUID.test(pessoa) || !PAPEIS.includes(papel)) return { erro: "Dados inválidos." };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("alterar_papel_ministerio", {
    p_ministerio: id,
    p_perfil: pessoa,
    p_papel: papel,
  });
  atualizarTelas(id);
  return error ? { erro: traduzirErro(error) } : {};
}

export async function removerParticipante(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const id = String(formData.get("id") ?? "");
  const pessoa = String(formData.get("pessoa") ?? "");
  if (!UUID.test(id) || !UUID.test(pessoa)) return { erro: "Dados inválidos." };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("remover_participante", { p_ministerio: id, p_perfil: pessoa });
  atualizarTelas(id);
  return error ? { erro: traduzirErro(error) } : {};
}
