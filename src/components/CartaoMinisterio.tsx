// Cartão de um ministério na lista: nome, descrição curta e situação, com o cartão inteiro
// como área de toque (≥ 44 px) que leva ao detalhe.
import Link from "next/link";
import type { Ministerio } from "@/lib/ministerios/consultas";

export function CartaoMinisterio({ ministerio }: { ministerio: Ministerio }) {
  return (
    <Link
      href={`/ministerios/${ministerio.id}`}
      className="flex min-h-14 flex-col gap-1 rounded-lg border border-slate-400 p-4 hover:bg-slate-50 focus:outline-3 focus:outline-offset-2 focus:outline-blue-700"
    >
      <span className="text-lg font-semibold text-blue-950">
        {ministerio.nome}
        {!ministerio.ativo && (
          <span className="ml-2 rounded bg-slate-200 px-2 py-0.5 text-sm font-medium text-slate-800">Desativado</span>
        )}
      </span>
      {ministerio.descricao && <span className="text-base text-slate-800">{ministerio.descricao}</span>}
    </Link>
  );
}
