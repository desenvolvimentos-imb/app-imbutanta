import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { obterSessao } from "@/lib/auth/sessao";
import { FormularioRedefinir } from "./formulario";

export const metadata: Metadata = { title: "Nova senha" };

export default async function PaginaRedefinir() {
  // Só chega aqui quem abriu um link válido de recuperação (que abre uma sessão temporária).
  const perfil = await obterSessao();
  if (!perfil) redirect("/recuperar-senha?erro=link");

  return (
    <>
      <h1 className="text-2xl font-bold">Criar nova senha</h1>
      <FormularioRedefinir />
    </>
  );
}
