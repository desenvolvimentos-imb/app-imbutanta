// Visão da grade por data: um cartão por data, com os totais, a contagem por função e as pessoas
// em três grupos. É a visão padrão no celular (sem rolagem horizontal da página).
import { ContagemPorFuncao } from "@/components/ContagemPorFuncao";
import { SeloDisponibilidade } from "@/components/SeloDisponibilidade";
import type { GradeConsulta, SituacaoNaData } from "@/lib/disponibilidade/consultas";
import { formatarDataConsulta } from "@/lib/disponibilidade/datas";

const GRUPOS: { situacao: SituacaoNaData; titulo: string }[] = [
  { situacao: "disponivel", titulo: "Disponíveis" },
  { situacao: "indisponivel", titulo: "Indisponíveis" },
  { situacao: "sem_resposta", titulo: "Sem resposta" },
];

export function VisaoPorData({ grade, podeCorrigir = false }: { grade: GradeConsulta; podeCorrigir?: boolean }) {
  return (
    <ul className="flex flex-col gap-4">
      {grade.datas.map((d) => (
        <li key={d.id} className="flex flex-col gap-3 rounded-lg border border-slate-400 p-4">
          <div>
            <p className="text-lg font-semibold">
              {formatarDataConsulta(d.data)}
              {d.rotulo && <span className="font-normal text-slate-800"> · {d.rotulo}</span>}
            </p>
            <p className="text-base">
              {d.disponiveis} {d.disponiveis === 1 ? "disponível" : "disponíveis"}
              {d.passada && <span className="text-slate-700"> · já passou</span>}
            </p>
          </div>
          <ContagemPorFuncao itens={d.por_funcao} />
          {GRUPOS.map((g) => {
            const pessoas = grade.participantes.filter((p) => (p.respostas[d.id]?.resposta ?? "sem_resposta") === g.situacao);
            return (
              <div key={g.situacao} className="flex flex-col gap-1">
                <p className="text-sm font-semibold text-slate-800">{g.titulo} ({pessoas.length})</p>
                {pessoas.length === 0 ? (
                  <p className="text-base text-slate-600">Ninguém.</p>
                ) : (
                  <ul className="flex flex-col gap-1">
                    {pessoas.map((p) => (
                      <li key={p.perfil_id} className="flex flex-wrap items-center gap-2 text-base">
                        {p.nome}
                        {podeCorrigir && (
                          <a href={`#corrigir-${p.perfil_id}`} aria-label={`Corrigir respostas de ${p.nome}`}
                             className="inline-flex min-h-11 items-center px-1 text-base font-medium text-blue-900 underline">Corrigir</a>
                        )}
                        {p.nao_respondeu && g.situacao === "sem_resposta" && (
                          <span className="rounded border border-amber-800 bg-amber-50 px-1.5 text-sm font-semibold text-amber-950">Ainda não respondeu</span>
                        )}
                        {p.respostas[d.id]?.preenchida_pelo_lider && (
                          <SeloDisponibilidade situacao={g.situacao} preenchidaPeloLider />
                        )}
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            );
          })}
        </li>
      ))}
    </ul>
  );
}
