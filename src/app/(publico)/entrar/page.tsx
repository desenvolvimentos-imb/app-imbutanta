import type { Metadata } from "next";
import Link from "next/link";
import { BotaoGoogle } from "@/components/BotaoGoogle";
import { MensagemInfo } from "@/components/MensagemErro";
import { caminhoVoltarSeguro } from "@/lib/auth/redirecionamento";
import { redirecionarSeLogado } from "@/lib/auth/sessao";
import { FormularioEntrar } from "./formulario";

export const metadata: Metadata = { title: "Entrar" };

const ERROS_DA_URL: Record<string, string> = {
  google: "Não foi possível entrar com o Google. Tente novamente.",
  link: "Este link expirou ou já foi usado. Entre com o seu email e senha ou peça um novo link.",
};

const INFOS_DA_URL: Record<string, string> = {
  senha: "A sua senha foi alterada. Entre com a nova senha.",
  excluida: "A sua conta e os seus dados foram excluídos.",
};

export default async function PaginaEntrar({ searchParams }: PageProps<"/entrar">) {
  await redirecionarSeLogado();

  const params = await searchParams;
  const voltarBruto = typeof params.voltar === "string" ? params.voltar : undefined;
  // Só guardamos o `voltar` se for um caminho interno seguro.
  const voltar = voltarBruto ? caminhoVoltarSeguro(voltarBruto, "") || undefined : undefined;
  const erroUrl = typeof params.erro === "string" ? ERROS_DA_URL[params.erro] : undefined;

  const infoUrl = typeof params.ok === "string" ? INFOS_DA_URL[params.ok] : undefined;

  return (
    <>
      <h1 className="text-2xl font-bold">Entrar</h1>
      <MensagemInfo texto={infoUrl} />
      <BotaoGoogle voltar={voltar} />
      <p className="text-center text-slate-700">ou use o seu email</p>
      <FormularioEntrar voltar={voltar} erroInicial={erroUrl} />
      <p className="text-center">
        <Link href="/recuperar-senha" className="font-semibold text-blue-900 underline">
          Esqueci a minha senha
        </Link>
      </p>
      <p className="text-center">
        Ainda não tem conta?{" "}
        <Link href="/cadastrar" className="font-semibold text-blue-900 underline">
          Criar conta
        </Link>
      </p>
    </>
  );
}
