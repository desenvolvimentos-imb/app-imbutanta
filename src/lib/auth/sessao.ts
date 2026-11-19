// Lê quem está logado e qual é a situação/papel dessa pessoa, SEMPRE do banco
// (não do token): mudanças de papel valem sem novo login (RF-026).
import { cache } from "react";
import { redirect } from "next/navigation";
import { criarClienteServidor } from "@/lib/supabase/server";
import { destinoPara, rotaDaSituacao, type Papel, type Situacao } from "./permissoes";

export type Perfil = {
  id: string;
  nome: string;
  email: string;
  situacao: Situacao;
  papel: Papel;
};

// `cache` evita consultar duas vezes na mesma requisição (layout + página).
export const obterSessao = cache(async (): Promise<Perfil | null> => {
  const supabase = await criarClienteServidor();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data } = await supabase
    .from("perfis")
    .select("id, nome, email, situacao, papel")
    .eq("id", user.id)
    .maybeSingle();

  // Sem perfil (não deveria acontecer): trata como pendente, ou seja, sem acesso algum.
  return (
    (data as Perfil | null) ?? {
      id: user.id,
      nome: user.email ?? "",
      email: user.email ?? "",
      situacao: "pendente",
      papel: "membro",
    }
  );
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
  const destino = destinoPara(perfil.situacao, perfil.papel, rota);
  if (destino) redirect(destino);
  return perfil;
}

// Para entrar/cadastrar: quem já está logado vai direto para a tela certa.
export async function redirecionarSeLogado(): Promise<void> {
  const perfil = await obterSessao();
  if (perfil) redirect(rotaDaSituacao(perfil.situacao));
}
