// Depois de entrar (senha, Google ou link de email), decide para onde a pessoa vai:
// aprovados voltam à página que tentavam abrir (se houver); os demais vão à tela da situação.
import type { SupabaseClient } from "@supabase/supabase-js";
import { caminhoVoltarSeguro } from "./redirecionamento";
import { destinoPara, rotaDaSituacao, type Papel, type Situacao } from "./permissoes";
import { lideraAlgumMinisterio } from "./lideranca";

export async function destinoPosLogin(supabase: SupabaseClient, voltar?: string | null): Promise<string> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return "/entrar";

  const { data } = await supabase.from("perfis").select("situacao, papel").eq("id", user.id).maybeSingle();
  const situacao = (data?.situacao as Situacao | undefined) ?? "pendente";
  const papel = (data?.papel as Papel | undefined) ?? "membro";

  if (situacao !== "aprovado") return rotaDaSituacao(situacao);

  const alvo = caminhoVoltarSeguro(voltar);
  // Se o papel não permite a página pedida, cai no início.
  const caminho = alvo.split(/[?#]/)[0];
  const lidera = await lideraAlgumMinisterio(supabase);
  return destinoPara(situacao, papel, caminho, lidera) ? "/inicio" : alvo;
}
