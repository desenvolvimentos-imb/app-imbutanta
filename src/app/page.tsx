// A raiz só encaminha: quem está logado vai para a própria tela; quem não está, para o login
// (o proxy.ts já cuida do segundo caso).
import { redirect } from "next/navigation";
import { exigirSessao } from "@/lib/auth/sessao";
import { rotaDaSituacao } from "@/lib/auth/permissoes";

export default async function Raiz() {
  const perfil = await exigirSessao();
  redirect(rotaDaSituacao(perfil.situacao));
}
