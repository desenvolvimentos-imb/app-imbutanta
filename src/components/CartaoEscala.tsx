// Item de lista de escalas: evento, data e horário, situação e (para o gestor) o que precisa de atenção.
import Link from "next/link";
import { DestaqueVaga } from "@/components/DestaqueVaga";
import type { EscalaResumo, SituacaoEscala } from "@/lib/escalas/consultas";
import { formatarDataHora } from "@/lib/escalas/datas";

const SELO: Record<SituacaoEscala, { texto: string; classes: string }> = {
  rascunho: { texto: "Rascunho", classes: "bg-slate-200 text-slate-900" },
  publicada: { texto: "Publicada", classes: "bg-blue-100 text-blue-950" },
  cancelada: { texto: "Cancelada", classes: "bg-red-100 text-red-950" },
};

export function SeloSituacao({ situacao }: { situacao: SituacaoEscala }) {
  const s = SELO[situacao];
  return <span className={`rounded px-2 py-0.5 text-sm font-medium ${s.classes}`}>{s.texto}</span>;
}

export function CartaoEscala({ ministerioId, escala }: { ministerioId: string; escala: EscalaResumo }) {
  const ehGestor = escala.recusadas !== null;
  return (
    <li className="rounded-lg border border-slate-400">
      <Link href={`/ministerios/${ministerioId}/escalas/${escala.id}`} className="flex flex-col gap-2 p-4 focus:outline-3 focus:outline-offset-2 focus:outline-blue-700">
        <div className="flex items-start justify-between gap-2">
          <p className="text-lg font-semibold">{escala.evento}</p>
          <SeloSituacao situacao={escala.situacao} />
        </div>
        <p className="text-base text-slate-800">{formatarDataHora(escala.data, escala.horario)}</p>
        <p className="text-base text-slate-800">
          {escala.total_vagas} {escala.total_vagas === 1 ? "vaga" : "vagas"}
        </p>
        <div className="flex flex-wrap gap-2">
          {escala.vagas_abertas > 0 && <DestaqueVaga tipo="em_aberto" />}
          {ehGestor && (escala.recusadas ?? 0) > 0 && <DestaqueVaga tipo="recusada" />}
          {ehGestor && (escala.sem_resposta ?? 0) > 0 && <DestaqueVaga tipo="sem_resposta" />}
        </div>
      </Link>
    </li>
  );
}
