import type { Metadata } from "next";
import { exigirAcesso } from "@/lib/auth/sessao";
import { listarPessoasAprovadas } from "@/lib/ministerios/consultas";
import { FormularioNovoMinisterio } from "./formulario";

export const metadata: Metadata = { title: "Novo ministério" };

export default async function PaginaNovoMinisterio() {
  // Somente administrador. O banco (criar_ministerio) também só aceita administrador.
  await exigirAcesso("/ministerios/novo");
  const pessoas = await listarPessoasAprovadas();

  return (
    <>
      <h1 className="text-2xl font-bold">Novo ministério</h1>
      <FormularioNovoMinisterio pessoas={pessoas} />
    </>
  );
}
