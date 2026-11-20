"use server";
// Pedir ministérios pela tela de espera (RF-015, RF-017): é o caminho de quem entrou por Google
// (sem formulário de cadastro) e de quem não marcou nada no cadastro. Cada ministério vira um
// pedido; a regra de verdade está na função SQL `pedir_entrada_ministerio`.
import { revalidatePath } from "next/cache";
import { criarClienteServidor } from "@/lib/supabase/server";
import { traduzirErro } from "@/lib/auth/mensagens-erro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { validarIdsMinisterios } from "@/lib/ministerios/validacao";

// Repetir um pedido ou pedir onde já participa não é problema para quem marcou vários: ignora.
const IGNORAR = ["pedido_duplicado", "ja_participa"];

export async function pedirMinisterios(_anterior: EstadoForm, formData: FormData): Promise<EstadoForm> {
  const ids = validarIdsMinisterios(formData.getAll("ministerios"));
  if (ids.length === 0) return { erro: "Marque pelo menos um ministério." };

  const supabase = await criarClienteServidor();
  let erro: string | undefined;
  for (const id of ids) {
    const { error } = await supabase.rpc("pedir_entrada_ministerio", { p_ministerio: id });
    if (error && !IGNORAR.includes(error.message)) erro ??= traduzirErro(error);
  }

  revalidatePath("/aguardando-aprovacao");
  return erro ? { erro } : {};
}
