// Lê quem está logado e qual é a situação/papel dessa pessoa, SEMPRE do banco
// (não do token): mudanças de papel valem sem novo login (RF-026).
import { cache } from "react";
import { redirect } from "next/navigation";
import { criarClienteServidor } from "@/lib/supabase/server";
import { destinoPara, rotaDaSituacao } from "./permissoes";
import { perfilOuFalha, type Perfil } from "./perfil";
import { lideraAlgumMinisterio } from "./lideranca";

export type { Perfil } from "./perfil";

// `cache` evita consultar duas vezes na mesma requisição (layout + página).
export const obterSessao = cache(async (): Promise<Perfil | null> => {
  const supabase = await criarClienteServidor();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const consulta = await supabase
    .from("perfis")
    .select("id, nome, email, situacao, papel")
    .eq("id", user.id)
    .maybeSingle();

  // Falha do banco ou perfil ausente viram um erro claro (ver perfil.ts), não "pendente".
  const perfil = perfilOuFalha(consulta as Parameters<typeof perfilOuFalha>[0], user);

  // Liderança é por ministério: só vale para conta aprovada (a função do banco já confere).
  const lidera = perfil.situacao === "aprovado" ? await lideraAlgumMinisterio(supabase) : false;
  return { ...perfil, lidera };
});

// Para páginas que exigem login: sem sessão, vai para /entrar.
export async function exigirSessao(): Promise<Perfil> {
  const perfil = await obterSessao();
  if (!perfil) redirect("/entrar");
  return perfil;
}

// Para páginas do grupo (app): exige conta aprovada e o papel permitido para a rota.
export async function exigirAcesso(rota: string): Promise<Perfil> {
  const perfil = await exigirSessao();
  const destino = destinoPara(perfil.situacao, perfil.papel, rota, perfil.lidera);
  if (destino) redirect(destino);
  return perfil;
}

// Para entrar/cadastrar: quem já está logado vai direto para a tela certa.
export async function redirecionarSeLogado(): Promise<void> {
  const perfil = await obterSessao();
  if (perfil) redirect(rotaDaSituacao(perfil.situacao));
}
