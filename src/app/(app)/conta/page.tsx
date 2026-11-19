import type { Metadata } from "next";
import { BotaoSair } from "@/components/BotaoSair";
import { ExcluirConta } from "@/components/ExcluirConta";
import { exigirAcesso } from "@/lib/auth/sessao";

export const metadata: Metadata = { title: "Minha conta" };

const NOMES_PAPEL = { membro: "Membro", lider: "Líder de ministério", administrador: "Administrador" } as const;

export default async function PaginaConta() {
  const perfil = await exigirAcesso("/conta");
  return (
    <>
      <h1 className="text-2xl font-bold">Minha conta</h1>
      <dl className="flex flex-col gap-3 text-lg">
        <div>
          <dt className="text-sm text-slate-700">Nome</dt>
          <dd>{perfil.nome}</dd>
        </div>
        <div>
          <dt className="text-sm text-slate-700">Email</dt>
          <dd>{perfil.email}</dd>
        </div>
        <div>
          <dt className="text-sm text-slate-700">Papel</dt>
          <dd>{NOMES_PAPEL[perfil.papel]}</dd>
        </div>
      </dl>
      <BotaoSair />
      <ExcluirConta />
    </>
  );
}
