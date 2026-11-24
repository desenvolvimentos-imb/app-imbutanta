"use server";
// Escalas e vagas (FR-005 a FR-018). A regra de verdade está nas funções SQL (só o gestor, datas,
// função ativa, participante do ministério, avisos); aqui validamos o formato e repassamos,
// traduzindo os erros.
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { criarClienteServidor } from "@/lib/supabase/server";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { lerAvisos } from "@/lib/escalas/avisos";
import type { EstadoVaga } from "@/lib/escalas/estado";
import {
  validarData, validarEscala, validarEvento, validarHorario, validarId, validarObservacao, validarRotulo,
} from "@/lib/escalas/validacao";

function atualizar(ministerioId: string, escalaId?: string) {
  revalidatePath(`/ministerios/${ministerioId}`);
  revalidatePath(`/ministerios/${ministerioId}/escalas`);
  if (escalaId) revalidatePath(`/ministerios/${ministerioId}/escalas/${escalaId}`);
  revalidatePath("/minhas-escalas");
}

function valoresEscala(formData: FormData) {
  const texto = (campo: string) => String(formData.get(campo) ?? "");
  return { evento: texto("evento"), data: texto("data"), horario: texto("horario"), observacao: texto("observacao") };
}

function errosEscala(formData: FormData): { erros: Record<string, string> } | null {
  const erros: Record<string, string> = {};
  const verificacoes = [
    ["evento", validarEvento(formData.get("evento"))],
    ["data", validarData(formData.get("data"))],
    ["horario", validarHorario(formData.get("horario"))],
    ["observacao", validarObservacao(formData.get("observacao"))],
  ] as const;
  for (const [campo, resultado] of verificacoes) {
    if (!resultado.ok) erros[campo] = resultado.mensagem;
  }
  return Object.keys(erros).length > 0 ? { erros } : null;
}

export async function criarEscala(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const valores = valoresEscala(formData);
  if (!ministerio.ok) return { erro: "Ministério não encontrado.", valores };
  const invalido = errosEscala(formData);
  if (invalido) return { ...invalido, valores };
  const dados = validarEscala(valores);
  if (!dados.ok) return { erro: dados.mensagem, valores };

  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc("criar_escala", {
    p_ministerio: ministerio.valor,
    p_evento: dados.valor.evento,
    p_data: dados.valor.data,
    p_horario: dados.valor.horario,
    p_observacao: dados.valor.observacao,
  });
  if (error || !data) return { erro: traduzirErro(error), valores };
  atualizar(ministerio.valor);
  // `redirect` lança uma exceção especial do Next.js: precisa ficar fora de try/catch.
  redirect(`/ministerios/${ministerio.valor}/escalas/${(data as { id: string }).id}`);
}

export async function editarEscala(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const escala = validarId(formData.get("escala"));
  const valores = valoresEscala(formData);
  if (!ministerio.ok || !escala.ok) return { erro: "Escala não encontrada.", valores };
  const invalido = errosEscala(formData);
  if (invalido) return { ...invalido, valores };
  const dados = validarEscala(valores);
  if (!dados.ok) return { erro: dados.mensagem, valores };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("editar_escala", {
    p_escala: escala.valor,
    p_evento: dados.valor.evento,
    p_data: dados.valor.data,
    p_horario: dados.valor.horario,
    p_observacao: dados.valor.observacao,
  });
  atualizar(ministerio.valor, escala.valor);
  if (error) return { erro: traduzirErro(error), valores };
  return { info: "Alterações salvas." };
}

/**
 * Cria ou altera uma vaga. Quando há avisos (outro ministério no mesmo dia, falta de aptidão), o
 * banco NÃO grava e devolve os avisos; o líder decide continuar e o formulário reenvia com `ciente`.
 */
export async function salvarVaga(_anterior: EstadoVaga, formData: FormData): Promise<EstadoVaga> {
  const ministerio = validarId(formData.get("ministerio"));
  const escala = validarId(formData.get("escala"));
  const funcao = validarId(formData.get("funcao"));
  const rotulo = validarRotulo(formData.get("rotulo"));
  const vagaBruta = String(formData.get("vaga") ?? "");
  const pessoaBruta = String(formData.get("pessoa") ?? "");
  const vaga = vagaBruta ? validarId(vagaBruta) : null;
  const pessoa = pessoaBruta ? validarId(pessoaBruta) : null;
  const ciente = formData.get("ciente") === "1";

  if (!ministerio.ok || !escala.ok || (vaga && !vaga.ok) || (pessoa && !pessoa.ok)) return { erro: "Vaga não encontrada." };
  if (!funcao.ok) return { erros: { funcao: "Escolha a função da vaga." } };
  if (!rotulo.ok) return { erros: { rotulo: rotulo.mensagem } };

  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc("salvar_vaga", {
    p_escala: escala.valor,
    p_vaga: vaga?.ok ? vaga.valor : null,
    p_funcao: funcao.valor,
    p_rotulo: rotulo.valor,
    p_perfil: pessoa?.ok ? pessoa.valor : null,
    p_ciente: ciente,
  });
  atualizar(ministerio.valor, escala.valor);
  if (error) return { erro: traduzirErro(error) };

  const resultado = data as { salvo: boolean; avisos?: unknown };
  // Devolve os valores digitados: o React limpa o formulário depois de cada ação, e o líder precisa
  // reenviar exatamente a mesma vaga ao tocar em "Continuar mesmo assim".
  if (!resultado.salvo) {
    return {
      avisos: lerAvisos(resultado.avisos),
      valores: { funcao: funcao.valor, rotulo: rotulo.valor, pessoa: pessoa?.ok ? pessoa.valor : "" },
    };
  }
  return { info: "Vaga salva." };
}

export async function removerVaga(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const escala = validarId(formData.get("escala"));
  const vaga = validarId(formData.get("vaga"));
  if (!ministerio.ok || !escala.ok || !vaga.ok) return { erro: "Vaga não encontrada." };
  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("remover_vaga", { p_vaga: vaga.valor });
  atualizar(ministerio.valor, escala.valor);
  return error ? { erro: traduzirErro(error) } : {};
}

async function mudarSituacao(formData: FormData, rpc: "publicar_escala" | "cancelar_escala"): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const escala = validarId(formData.get("escala"));
  if (!ministerio.ok || !escala.ok) return { erro: "Escala não encontrada." };
  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc(rpc, { p_escala: escala.valor });
  atualizar(ministerio.valor, escala.valor);
  return error ? { erro: traduzirErro(error) } : {};
}

export async function publicarEscala(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  return mudarSituacao(formData, "publicar_escala");
}

export async function cancelarEscala(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  return mudarSituacao(formData, "cancelar_escala");
}
