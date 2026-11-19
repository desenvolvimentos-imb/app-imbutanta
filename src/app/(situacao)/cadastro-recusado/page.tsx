import type { Metadata } from "next";
import { TelaSituacao } from "@/components/TelaSituacao";
import { exigirAcesso } from "@/lib/auth/sessao";

export const metadata: Metadata = { title: "Cadastro não aprovado" };

export default async function PaginaRecusado() {
  await exigirAcesso("/cadastro-recusado");
  return (
    <TelaSituacao titulo="Cadastro não aprovado">
      <p>O seu cadastro não foi aprovado e, por isso, você não tem acesso ao conteúdo do app.</p>
      <p>Se acha que houve um engano, fale com a liderança da igreja.</p>
    </TelaSituacao>
  );
}
