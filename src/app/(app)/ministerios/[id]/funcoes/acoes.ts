"use server";
// Funções do ministério e aptidões dos participantes (FR-001 a FR-004). A regra de verdade está nas
// funções SQL (só o gestor, nome único entre ativas, função do próprio ministério); aqui validamos o
// formato e repassamos, traduzindo os erros.
import { revalidatePath } from "next/cache";
import { criarClienteServidor } from "@/lib/supabase/server";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { validarId, validarNomeFuncao } from "@/lib/escalas/validacao";

function atualizar(ministerioId: string) {
  revalidatePath(`/ministerios/${ministerioId}/funcoes`);
  revalidatePath(`/ministerios/${ministerioId}`);
}

export async function criarFuncao(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const nome = validarNomeFuncao(formData.get("nome"));
  const valores = { nome: String(formData.get("nome") ?? "") };
  if (!ministerio.ok) return { erro: "Ministério não encontrado.", valores };
  if (!nome.ok) return { erros: { nome: nome.mensagem }, valores };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("criar_funcao", { p_ministerio: ministerio.valor, p_nome: nome.valor });
  atualizar(ministerio.valor);
  if (error) return { erro: traduzirErro(error), valores };
  return { info: "Função criada." };
}

export async function renomearFuncao(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const funcao = validarId(formData.get("funcao"));
  const nome = validarNomeFuncao(formData.get("nome"));
  if (!ministerio.ok || !funcao.ok) return { erro: "Função não encontrada." };
  if (!nome.ok) return { erros: { nome: nome.mensagem } };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("editar_funcao", { p_funcao: funcao.valor, p_nome: nome.valor });
  atualizar(ministerio.valor);
  return error ? { erro: traduzirErro(error) } : { info: "Nome alterado." };
}

async function mudarSituacao(formData: FormData, rpc: "desativar_funcao" | "reativar_funcao"): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const funcao = validarId(formData.get("funcao"));
  if (!ministerio.ok || !funcao.ok) return { erro: "Função não encontrada." };
  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc(rpc, { p_funcao: funcao.valor });
  atualizar(ministerio.valor);
  return error ? { erro: traduzirErro(error) } : {};
}

export async function desativarFuncao(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  return mudarSituacao(formData, "desativar_funcao");
}

export async function reativarFuncao(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  return mudarSituacao(formData, "reativar_funcao");
}

/**
 * Salva a lista COMPLETA de aptidões de uma pessoa. Os campos chegam como `apto-<id da função>` com
 * o valor "", "principal" ou "secundaria"; vazio significa "não é apta" e a função fica fora da lista.
 */
export async function salvarAptidoes(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const pessoa = validarId(formData.get("pessoa"));
  if (!ministerio.ok || !pessoa.ok) return { erro: "Pessoa não encontrada." };

  const aptidoes: { funcao: string; tipo: string }[] = [];
  for (const [campo, valor] of formData.entries()) {
    if (!campo.startsWith("apto-")) continue;
    const funcao = validarId(campo.slice("apto-".length));
    if (!funcao.ok) return { erro: "Função inválida." };
    if (valor === "") continue;
    aptidoes.push({ funcao: funcao.valor, tipo: String(valor) });
  }

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("definir_aptidoes", {
    p_ministerio: ministerio.valor,
    p_perfil: pessoa.valor,
    p_aptidoes: aptidoes,
  });
  atualizar(ministerio.valor);
  return error ? { erro: traduzirErro(error) } : { info: "Aptidões salvas." };
}
