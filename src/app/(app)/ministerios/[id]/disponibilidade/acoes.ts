"use server";
// Consultas de disponibilidade (RF-001 a RF-013, RF-021). A regra de verdade está nas funções SQL
// (só o gestor, datas, prazo, unicidade, confirmação); aqui validamos o formato e repassamos,
// traduzindo os erros.
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { criarClienteServidor } from "@/lib/supabase/server";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { EstadoRemocao } from "@/lib/disponibilidade/estado";
import {
  validarConsulta, validarDatas, validarId, validarPrazo, validarRespostas,
} from "@/lib/disponibilidade/validacao";

function atualizar(ministerioId: string, consultaId?: string) {
  revalidatePath(`/ministerios/${ministerioId}`);
  revalidatePath(`/ministerios/${ministerioId}/disponibilidade`);
  if (consultaId) revalidatePath(`/ministerios/${ministerioId}/disponibilidade/${consultaId}`);
  revalidatePath("/disponibilidade");
  revalidatePath("/inicio");
}

const texto = (formData: FormData, campo: string) => String(formData.get(campo) ?? "");

/** Lê a lista de datas que o seletor envia como JSON num campo escondido. */
function lerDatas(formData: FormData): unknown {
  try {
    return JSON.parse(texto(formData, "datas") || "[]");
  } catch {
    return [];
  }
}

export async function criarConsulta(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const valores = {
    titulo: texto(formData, "titulo"), mensagem: texto(formData, "mensagem"),
    prazo: texto(formData, "prazo"), datas: texto(formData, "datas"),
  };
  if (!ministerio.ok) return { erro: "Ministério não encontrado.", valores };
  const dados = validarConsulta(valores);
  if (!dados.ok) return { erro: dados.mensagem, valores };
  const datas = validarDatas(lerDatas(formData));
  if (!datas.ok) return { erro: datas.mensagem, valores };

  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.rpc("criar_consulta", {
    p_ministerio: ministerio.valor,
    p_titulo: dados.valor.titulo,
    p_mensagem: dados.valor.mensagem,
    p_prazo: dados.valor.prazo,
    p_datas: datas.valor,
  });
  if (error || !data) return { erro: traduzirErro(error), valores };
  atualizar(ministerio.valor);
  // `redirect` lança uma exceção especial do Next.js: precisa ficar fora de try/catch.
  redirect(`/ministerios/${ministerio.valor}/disponibilidade/${(data as { id: string }).id}`);
}

export async function editarConsulta(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const consulta = validarId(formData.get("consulta"));
  const valores = { titulo: texto(formData, "titulo"), mensagem: texto(formData, "mensagem"), prazo: texto(formData, "prazo") };
  if (!ministerio.ok || !consulta.ok) return { erro: "Consulta não encontrada.", valores };
  const dados = validarConsulta(valores);
  if (!dados.ok) return { erro: dados.mensagem, valores };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("editar_consulta", {
    p_consulta: consulta.valor,
    p_titulo: dados.valor.titulo,
    p_mensagem: dados.valor.mensagem,
    p_prazo: dados.valor.prazo,
  });
  atualizar(ministerio.valor, consulta.valor);
  if (error) return { erro: traduzirErro(error), valores };
  return { info: "Alterações salvas." };
}

export async function adicionarDatas(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const consulta = validarId(formData.get("consulta"));
  if (!ministerio.ok || !consulta.ok) return { erro: "Consulta não encontrada." };
  const datas = validarDatas(lerDatas(formData));
  if (!datas.ok) return { erro: datas.mensagem };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("adicionar_datas_consulta", { p_consulta: consulta.valor, p_datas: datas.valor });
  atualizar(ministerio.valor, consulta.valor);
  if (error) return { erro: traduzirErro(error) };
  return { info: "Datas adicionadas. Elas começam sem resposta para todos." };
}

/** Remove uma data. Com respostas, o banco pede confirmação e a ação devolve a contagem. */
export async function removerData(_anterior: EstadoRemocao, formData: FormData): Promise<EstadoRemocao> {
  const ministerio = validarId(formData.get("ministerio"));
  const consulta = validarId(formData.get("consulta"));
  const data = validarId(formData.get("data"));
  if (!ministerio.ok || !consulta.ok || !data.ok) return { erro: "Data não encontrada." };
  const confirmado = formData.get("confirmado") === "1";

  const supabase = await criarClienteServidor();
  const { data: resultado, error } = await supabase.rpc("remover_data_consulta", {
    p_data: data.valor,
    p_confirmado: confirmado,
  });
  if (error) return { erro: traduzirErro(error) };
  const r = resultado as { removida: boolean; confirmacao_necessaria?: boolean; respostas?: number };
  if (!r.removida && r.confirmacao_necessaria) {
    return { confirmacao: { dataId: data.valor, respostas: r.respostas ?? 0 } };
  }
  atualizar(ministerio.valor, consulta.valor);
  return { info: "Data removida." };
}

export async function fecharConsulta(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const consulta = validarId(formData.get("consulta"));
  if (!ministerio.ok || !consulta.ok) return { erro: "Consulta não encontrada." };
  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("fechar_consulta", { p_consulta: consulta.valor });
  atualizar(ministerio.valor, consulta.valor);
  if (error) return { erro: traduzirErro(error) };
  return { info: "Consulta fechada." };
}

/** Reabre; se o prazo venceu, exige novo prazo ou a remoção do prazo (RF-008). */
export async function reabrirConsulta(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const consulta = validarId(formData.get("consulta"));
  if (!ministerio.ok || !consulta.ok) return { erro: "Consulta não encontrada." };
  const removerPrazo = formData.get("remover_prazo") === "1";
  const prazo = validarPrazo(formData.get("novo_prazo"));
  if (!prazo.ok) return { erro: prazo.mensagem };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("reabrir_consulta", {
    p_consulta: consulta.valor,
    p_prazo: removerPrazo ? null : prazo.valor,
    p_remover_prazo: removerPrazo,
  });
  atualizar(ministerio.valor, consulta.valor);
  if (error) return { erro: traduzirErro(error) };
  return { info: "Consulta reaberta." };
}

/** O líder preenche ou corrige as respostas de um participante (RF-021). */
export async function preencherResposta(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const ministerio = validarId(formData.get("ministerio"));
  const consulta = validarId(formData.get("consulta"));
  const perfil = validarId(formData.get("perfil"));
  if (!ministerio.ok || !consulta.ok || !perfil.ok) return { erro: "Pessoa não encontrada." };

  const ids = formData.getAll("datas_ids").map(String);
  const respostas = validarRespostas(
    ids.map((id) => ({ data_id: id, resposta: String(formData.get(`resp_${id}`) ?? "") || null })),
  );
  if (!respostas.ok) return { erro: respostas.mensagem };

  const supabase = await criarClienteServidor();
  const { error } = await supabase.rpc("preencher_disponibilidade", {
    p_consulta: consulta.valor,
    p_perfil: perfil.valor,
    p_respostas: respostas.valor,
  });
  atualizar(ministerio.valor, consulta.valor);
  if (error) return { erro: traduzirErro(error) };
  return { info: "Respostas salvas." };
}
