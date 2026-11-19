import type { Metadata } from "next";
import { TelaSituacao } from "@/components/TelaSituacao";
import { exigirAcesso } from "@/lib/auth/sessao";

export const metadata: Metadata = { title: "Aguardando aprovação" };

export default async function PaginaAguardando() {
  const perfil = await exigirAcesso("/aguardando-aprovacao");
  return (
    <TelaSituacao titulo="Aguardando aprovação">
      <p>Olá, {perfil.nome}! O seu cadastro foi recebido e está aguardando aprovação.</p>
      <p>Você ainda não tem acesso ao conteúdo do app. Assim que for aprovado, é só abrir o app de novo.</p>
    </TelaSituacao>
  );
}
