import type { Metadata } from "next";
import Link from "next/link";
import { FormularioRecuperar } from "./formulario";

export const metadata: Metadata = { title: "Recuperar senha" };

export default async function PaginaRecuperar({ searchParams }: PageProps<"/recuperar-senha">) {
  const params = await searchParams;
  const erroInicial =
    params.erro === "link" ? "Este link expirou ou já foi usado. Peça um novo abaixo." : undefined;

  return (
    <>
      <h1 className="text-2xl font-bold">Recuperar senha</h1>
      <p>Informe o seu email e enviaremos um link para criar uma nova senha.</p>
      <p className="rounded-lg bg-slate-100 p-3">
        Se você entra com o <strong>Google</strong>, não precisa de senha: recupere o acesso pela
        sua própria conta Google.
      </p>
      <FormularioRecuperar erroInicial={erroInicial} />
      <p className="text-center">
        <Link href="/entrar" className="font-semibold text-blue-900 underline">
          Voltar para entrar
        </Link>
      </p>
    </>
  );
}
