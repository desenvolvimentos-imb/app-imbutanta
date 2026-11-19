import type { Metadata } from "next";
import Link from "next/link";
import { BotaoGoogle } from "@/components/BotaoGoogle";
import { redirecionarSeLogado } from "@/lib/auth/sessao";
import { FormularioCadastro } from "./formulario";

export const metadata: Metadata = { title: "Criar conta" };

export default async function PaginaCadastrar() {
  await redirecionarSeLogado();

  return (
    <>
      <h1 className="text-2xl font-bold">Criar conta</h1>
      <BotaoGoogle />
      <p className="text-center text-slate-700">ou use o seu email</p>
      <FormularioCadastro />
      <p className="text-center text-sm text-slate-700">
        Ao criar a conta, você concorda com os{" "}
        <Link href="/termos" className="font-semibold text-blue-900 underline">
          Termos de Uso
        </Link>{" "}
        e a{" "}
        <Link href="/privacidade" className="font-semibold text-blue-900 underline">
          Política de Privacidade
        </Link>
        .
      </p>
      <p className="text-center">
        Já tem conta?{" "}
        <Link href="/entrar" className="font-semibold text-blue-900 underline">
          Entrar
        </Link>
      </p>
    </>
  );
}
