// Visão em tabela da grade: pessoa por linha, data por coluna. A primeira coluna (nome) fica fixa e
// só a tabela rola na horizontal, nunca a página inteira. O `relative` prende os textos só para
// leitor de tela (`sr-only`, posição absoluta) dentro da área rolável; sem ele, eles ficam fora dela
// e alargam a página.
import { SeloDisponibilidade } from "@/components/SeloDisponibilidade";
import type { GradeConsulta } from "@/lib/disponibilidade/consultas";
import { formatarDataConsulta } from "@/lib/disponibilidade/datas";

export function TabelaDisponibilidade({ grade }: { grade: GradeConsulta }) {
  // Funções que aparecem em alguma data, na ordem do banco (nome).
  const funcoes = grade.datas[0]?.por_funcao ?? [];
  return (
    <div className="relative overflow-x-auto rounded-lg border border-slate-400" tabIndex={0} role="region" aria-label="Grade de disponibilidade">
      <table className="min-w-full border-collapse text-left text-base">
        <thead>
          <tr className="bg-slate-100">
            <th scope="col" className="sticky left-0 z-10 min-w-40 bg-slate-100 p-2">Participante</th>
            {grade.datas.map((d) => (
              <th key={d.id} scope="col" className="min-w-36 p-2 font-semibold">
                {formatarDataConsulta(d.data)}
                {d.rotulo && <span className="block text-sm font-normal text-slate-700">{d.rotulo}</span>}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {grade.participantes.map((p) => (
            <tr key={p.perfil_id} className="border-t border-slate-300 align-top">
              <th scope="row" className="sticky left-0 z-10 bg-white p-2 font-medium">
                {p.nome}
                {p.nao_respondeu && (
                  <span className="mt-1 block rounded border border-amber-800 bg-amber-50 px-1.5 text-sm font-semibold text-amber-950">Ainda não respondeu</span>
                )}
                {p.observacao && <span className="mt-1 block text-sm font-normal text-slate-800">“{p.observacao}”</span>}
              </th>
              {grade.datas.map((d) => {
                const c = p.respostas[d.id];
                return (
                  <td key={d.id} className="p-2">
                    <SeloDisponibilidade situacao={c?.resposta ?? "sem_resposta"} preenchidaPeloLider={c?.preenchida_pelo_lider} />
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr className="border-t-2 border-slate-500 bg-slate-50 font-semibold">
            <th scope="row" className="sticky left-0 z-10 bg-slate-50 p-2">Disponíveis</th>
            {grade.datas.map((d) => <td key={d.id} className="p-2">{d.disponiveis}</td>)}
          </tr>
          {funcoes.map((f) => (
            <tr key={f.funcao_id} className="border-t border-slate-300">
              <th scope="row" className="sticky left-0 z-10 bg-white p-2 font-normal">{f.funcao}</th>
              {grade.datas.map((d) => {
                const item = d.por_funcao.find((x) => x.funcao_id === f.funcao_id);
                return (
                  <td key={d.id} className={`p-2 ${item?.faltando ? "font-semibold text-red-950" : ""}`}>
                    {item?.faltando && <span aria-hidden="true">⚠ </span>}
                    {item?.disponiveis ?? 0}
                    {item?.faltando && <span className="sr-only"> (sem disponíveis)</span>}
                  </td>
                );
              })}
            </tr>
          ))}
        </tfoot>
      </table>
    </div>
  );
}
