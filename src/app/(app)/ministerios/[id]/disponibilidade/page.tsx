import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { classesBotao } from "@/components/estilos-botao";
import { SeloConsulta } from "@/components/SeloDisponibilidade";
import { exigirAcesso } from "@/lib/auth/sessao";
import { listarConsultasMinisterio, type ResumoConsulta } from "@/lib/disponibilidade/consultas";
import { formatarDataCompleta } from "@/lib/disponibilidade/datas";
import { ehGestorDoMinisterio } from "@/lib/escalas/gestao";
import { obterMinisterio } from "@/lib/ministerios/consultas";

export const metadata: Metadata = { title: "Disponibilidade do ministério" };

function Cartao({ ministerioId, c }: { ministerioId: string; c: ResumoConsulta }) {
  return (
    <li>
      <Link href={`/ministerios/${ministerioId}/disponibilidade/${c.id}`}
            className="flex flex-col gap-2 rounded-lg border border-slate-400 p-4 focus:outline-3 focus:outline-offset-2 focus:outline-blue-700">
        <div className="flex items-start justify-between gap-2">
          <p className="text-lg font-semibold">{c.titulo}</p>
          <SeloConsulta aberta={c.aberta} motivo={c.motivo_fechada} />
        </div>
        <p className="text-base text-slate-800">
          {c.total_datas} {c.total_datas === 1 ? "data" : "datas"}
          {c.prazo && ` · prazo ${formatarDataCompleta(c.prazo)}`}
        </p>
        {c.aberta && c.sem_resposta_nenhuma > 0 && (
          <p className="text-base font-medium text-amber-950">
            {c.sem_resposta_nenhuma} {c.sem_resposta_nenhuma === 1 ? "pessoa ainda não respondeu" : "pessoas ainda não responderam"}
          </p>
        )}
      </Link>
    </li>
  );
}

// Lista de consultas do ministério: abertas e histórico. Só quem gere o ministério (líder ou
// administrador); os demais recebem "não encontrado". O banco confere de novo (RF-027).
export default async function PaginaConsultasMinisterio({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const perfil = await exigirAcesso(`/ministerios/${id}/disponibilidade`);
  const ministerio = await obterMinisterio(id);
  if (!ministerio || !(await ehGestorDoMinisterio(perfil, ministerio.id))) notFound();

  const consultas = await listarConsultasMinisterio(ministerio.id);
  const abertas = consultas.filter((c) => c.aberta);
  const historico = consultas.filter((c) => !c.aberta);

  return (
    <>
      <Link href={`/ministerios/${ministerio.id}`} className="text-base font-medium text-blue-900 underline">
        ← {ministerio.nome}
      </Link>
      <h1 className="text-2xl font-bold">Disponibilidade</h1>
      {ministerio.ativo && (
        <Link href={`/ministerios/${ministerio.id}/disponibilidade/nova`} className={classesBotao("primario")}>
          Nova consulta
        </Link>
      )}

      <section aria-labelledby="titulo-abertas" className="flex flex-col gap-3">
        <h2 id="titulo-abertas" className="text-lg font-semibold">Abertas</h2>
        {abertas.length === 0 ? (
          <p className="rounded-lg bg-slate-100 p-4 text-lg">Nenhuma consulta aberta.</p>
        ) : (
          <ul className="flex flex-col gap-3">{abertas.map((c) => <Cartao key={c.id} ministerioId={ministerio.id} c={c} />)}</ul>
        )}
      </section>

      <section aria-labelledby="titulo-historico" className="flex flex-col gap-3">
        <h2 id="titulo-historico" className="text-lg font-semibold">Histórico</h2>
        {historico.length === 0 ? (
          <p className="rounded-lg bg-slate-100 p-4 text-lg">Nenhuma consulta fechada.</p>
        ) : (
          <ul className="flex flex-col gap-3">{historico.map((c) => <Cartao key={c.id} ministerioId={ministerio.id} c={c} />)}</ul>
        )}
      </section>
    </>
  );
}
