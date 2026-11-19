import type { Metadata } from "next";
import { TelaSituacao } from "@/components/TelaSituacao";
import { exigirAcesso } from "@/lib/auth/sessao";

export const metadata: Metadata = { title: "Acesso removido" };

export default async function PaginaAcessoRemovido() {
  await exigirAcesso("/acesso-removido");
  return (
    <TelaSituacao titulo="Acesso removido">
      <p>O seu acesso ao app foi removido, por isso você não vê mais o conteúdo.</p>
      <p>Se acha que houve um engano, fale com a liderança da igreja.</p>
    </TelaSituacao>
  );
}
