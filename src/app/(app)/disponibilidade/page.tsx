import type { Metadata } from "next";
import Link from "next/link";
import { SeloConsulta } from "@/components/SeloDisponibilidade";
import { exigirAcesso } from "@/lib/auth/sessao";
import { minhasConsultas, type ConsultaParaResponder } from "@/lib/disponibilidade/consultas";
import { formatarDataCompleta } from "@/lib/disponibilidade/datas";

export const metadata: Metadata = { title: "Disponibilidade" };

function Cartao({ c }: { c: ConsultaParaResponder }) {
  return (
    <li>
      <Link href={`/disponibilidade/${c.id}`}
            className="flex flex-col gap-2 rounded-lg border border-slate-400 p-4 focus:outline-3 focus:outline-offset-2 focus:outline-blue-700">
        <p className="text-sm font-medium text-slate-700">{c.ministerio}</p>
        <div className="flex items-start justify-between gap-2">
          <p className="text-lg font-semibold">{c.titulo}</p>
          <SeloConsulta aberta={c.aberta} motivo={c.motivo_fechada} />
        </div>
        <p className="text-base text-slate-800">
          {c.datas.length} {c.datas.length === 1 ? "data" : "datas"}
          {c.prazo && ` · responda até ${formatarDataCompleta(c.prazo)}`}
        </p>
        {c.aberta && (
          <p className={`text-base font-medium ${c.sem_resposta > 0 ? "text-amber-950" : "text-green-950"}`}>
            {c.sem_resposta > 0
              ? `${c.sem_resposta} ${c.sem_resposta === 1 ? "data sem resposta" : "datas sem resposta"}`
              : "Tudo respondido"}
          </p>
        )}
      </Link>
    </li>
  );
}

// "Disponibilidade": as consultas abertas dos meus ministérios. A tela existe para todos; quem não
// participa de nenhum ministério vê o estado vazio. Cada pessoa vê só o que é dela (RF-020).
export default async function PaginaDisponibilidade() {
  await exigirAcesso("/disponibilidade");
  const { abertas, fechadas_recentes } = await minhasConsultas();

  return (
    <>
      <h1 className="text-2xl font-bold">Disponibilidade</h1>
      <p className="text-base text-slate-800">Diga em quais datas você pode ser escalado.</p>

      {abertas.length === 0 ? (
        <p className="rounded-lg bg-slate-100 p-4 text-lg">Nenhuma consulta aberta no momento.</p>
      ) : (
        <ul className="flex flex-col gap-3">{abertas.map((c) => <Cartao key={c.id} c={c} />)}</ul>
      )}

      {fechadas_recentes.length > 0 && (
        <section aria-labelledby="titulo-fechadas" className="flex flex-col gap-3">
          <h2 id="titulo-fechadas" className="text-lg font-semibold">Fechadas recentemente</h2>
          <ul className="flex flex-col gap-3">{fechadas_recentes.map((c) => <Cartao key={c.id} c={c} />)}</ul>
        </section>
      )}
    </>
  );
}
