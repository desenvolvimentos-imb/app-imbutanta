// Descobre se a pessoa logada lidera algum ministério ativo (RF-027). A regra está na função
// SQL `ministerios_que_lidero`, que só considera ministério ativo e conta aprovada; aqui só
// perguntamos. Lida do banco a cada chamada: mudar a liderança vale sem novo login (RF-034).
import type { SupabaseClient } from "@supabase/supabase-js";

export async function lideraAlgumMinisterio(supabase: SupabaseClient): Promise<boolean> {
  const { data, error } = await supabase.rpc("ministerios_que_lidero");
  if (error) {
    // Falha ao consultar não deve esconder as telas por engano nem derrubar o app: tratamos
    // como "não lidera" (o banco continua barrando qualquer ação indevida) e registramos.
    console.error("[lideranca] falha ao consultar os ministérios que a pessoa lidera", error.message);
    return false;
  }
  return Array.isArray(data) && data.length > 0;
}
