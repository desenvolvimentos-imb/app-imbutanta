import type { Metadata } from "next";
import Link from "next/link";
import { BotoesResposta } from "@/components/BotoesResposta";
import { classesBotao } from "@/components/estilos-botao";
import { SeloResposta } from "@/components/SeloResposta";
import { exigirAcesso } from "@/lib/auth/sessao";
import { minhasEscalas } from "@/lib/escalas/consultas";
import { formatarDataHora } from "@/lib/escalas/datas";

export const metadata: Metadata = { title: "Minhas escalas" };

// "Minhas escalas": a tela existe para todos, inclusive para quem não está escalado (FR-021).
// Em Next.js 16, `searchParams` é uma Promise e precisa de await.
export default async function PaginaMinhasEscalas({ searchParams }: { searchParams: Promise<{ passadas?: string }> }) {
  const { passadas } = await searchParams;
  const verPassadas = passadas === "1";
  await exigirAcesso("/minhas-escalas");
  const escalas = await minhasEscalas(verPassadas);

  return (
    <>
      <h1 className="text-2xl font-bold">Minhas escalas</h1>

      <nav aria-label="Período" className="grid grid-cols-2 gap-2">
        <Link href="/minhas-escalas" aria-current={verPassadas ? undefined : "page"} className={classesBotao(verPassadas ? "secundario" : "primario")}>
          Próximas
        </Link>
        <Link href="/minhas-escalas?passadas=1" aria-current={verPassadas ? "page" : undefined} className={classesBotao(verPassadas ? "primario" : "secundario")}>
          Passadas
        </Link>
      </nav>

      {escalas.length === 0 ? (
        <p className="rounded-lg bg-slate-100 p-4 text-lg">
          {verPassadas ? "Você não tem escalas passadas." : "Você não está escalado em nenhuma escala próxima."}
        </p>
      ) : (
        <ul className="flex flex-col gap-4">
          {escalas.map((e) => (
            <li key={e.escala_id} className="flex flex-col gap-3 rounded-lg border border-slate-400 p-4">
              <Link href={`/ministerios/${e.ministerio_id}/escalas/${e.escala_id}`}
                    className="flex flex-col gap-1 focus:outline-3 focus:outline-offset-2 focus:outline-blue-700">
                <p className="text-sm font-medium text-slate-700">{e.ministerio}</p>
                <p className="text-lg font-semibold">{e.evento}</p>
                <p className="text-base">{formatarDataHora(e.data, e.horario)}</p>
                <p className="text-base text-slate-800">Função: {e.funcoes.join(", ")}</p>
              </Link>
              {e.situacao === "cancelada" ? (
                <p role="status" className="rounded-lg border border-red-800 bg-red-50 p-2 text-base font-semibold text-red-950">
                  Cancelada
                </p>
              ) : (
                <div className="flex flex-col gap-1">
                  <p className="text-sm text-slate-800">Sua resposta</p>
                  <div><SeloResposta resposta={e.minha_resposta} /></div>
                  {e.minha_resposta === "recusado" && e.motivo && <p className="text-base text-slate-800">Motivo: {e.motivo}</p>}
                </div>
              )}
              {e.pode_responder && (
                <BotoesResposta escalaId={e.escala_id} ministerioId={e.ministerio_id} evento={e.evento} atual={e.minha_resposta} />
              )}
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
