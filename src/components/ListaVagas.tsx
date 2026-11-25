// Vagas de uma escala em modo de leitura: função, rótulo e quem ocupa (ou "Em aberto").
// O gestor recebe também a resposta, o motivo da recusa e o destaque (FR-022, FR-023).
import { DestaqueVaga } from "@/components/DestaqueVaga";
import { SeloDisponibilidade } from "@/components/SeloDisponibilidade";
import type { SituacaoNaData } from "@/lib/disponibilidade/consultas";
import type { VagaDaEscala } from "@/lib/escalas/consultas";

const ROTULO_RESPOSTA = { pendente: "Pendente", confirmado: "Confirmado", recusado: "Recusado" } as const;

export function ListaVagas({ vagas, disponibilidade = {} }: { vagas: VagaDaEscala[]; disponibilidade?: Record<string, SituacaoNaData> }) {
  if (vagas.length === 0) {
    return <p className="rounded-lg bg-slate-100 p-4 text-lg">Esta escala ainda não tem vagas.</p>;
  }
  return (
    <ul className="flex flex-col gap-3">
      {vagas.map((v) => (
        <li key={v.id} className="flex flex-col gap-2 rounded-lg border border-slate-400 p-4">
          <div className="flex items-start justify-between gap-2">
            <p className="text-lg font-semibold">
              {v.funcao}
              {v.rotulo && <span className="font-normal text-slate-800"> · {v.rotulo}</span>}
            </p>
            <DestaqueVaga tipo={v.precisa_atencao} />
          </div>
          <p className="text-base">
            {v.pessoa ? (
              <>
                {v.pessoa.nome}
                {v.minha && <span className="font-medium"> (você)</span>}
              </>
            ) : (
              <span className="font-medium">Em aberto</span>
            )}
          </p>
          {v.pessoa && disponibilidade[v.pessoa.id] && disponibilidade[v.pessoa.id] !== "disponivel" && (
            <p className="flex flex-wrap items-center gap-2 text-base">
              Disponibilidade nesta data: <SeloDisponibilidade situacao={disponibilidade[v.pessoa.id]} />
            </p>
          )}
          {v.resposta && (
            <p className="text-base text-slate-800">
              Resposta: {ROTULO_RESPOSTA[v.resposta]}
              {v.resposta === "recusado" && v.motivo ? ` — ${v.motivo}` : ""}
            </p>
          )}
        </li>
      ))}
    </ul>
  );
}
