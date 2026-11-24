"use client";
// Grade do líder (RF-022 a RF-025): a mesma informação em duas visões, com botão para alternar.
// Em tela estreita a visão por data é a padrão (sem rolagem horizontal da página); em tela larga,
// a tabela. A escolha do líder vale só nesta tela, sem guardar nada dele.
import { useState } from "react";
import { classesBotao } from "@/components/estilos-botao";
import { TabelaDisponibilidade } from "@/components/TabelaDisponibilidade";
import { VisaoPorData } from "@/components/VisaoPorData";
import type { GradeConsulta } from "@/lib/disponibilidade/consultas";

type Modo = "auto" | "data" | "tabela";

export function GradeDisponibilidade({ grade, hrefFuncoes }: { grade: GradeConsulta; hrefFuncoes: string }) {
  const [modo, setModo] = useState<Modo>("auto");
  const semResposta = grade.participantes.filter((p) => p.nao_respondeu);
  // "auto": visão por data no celular, tabela a partir de 768 px. Explícito: vale em qualquer tela.
  const classeData = modo === "auto" ? "min-w-0 md:hidden" : modo === "data" ? "min-w-0" : "hidden";
  const classeTabela = modo === "auto" ? "hidden min-w-0 max-w-full md:block" : modo === "tabela" ? "min-w-0 max-w-full" : "hidden";

  return (
    <section aria-labelledby="titulo-grade" className="flex min-w-0 max-w-full flex-col gap-4">
      <h2 id="titulo-grade" className="text-lg font-semibold">Respostas</h2>

      {semResposta.length > 0 && (
        <p role="status" className="rounded-lg border border-amber-800 bg-amber-50 p-3 text-base text-amber-950">
          <span className="font-semibold">Ainda não responderam ({semResposta.length}):</span> {semResposta.map((p) => p.nome).join(", ")}.
        </p>
      )}

      {!grade.tem_funcoes && (
        <p className="rounded-lg bg-slate-100 p-3 text-base">
          Cadastre as funções e aptidões para ver a contagem por função.{" "}
          <a href={hrefFuncoes} className="font-medium text-blue-900 underline">Funções e aptidões</a>
        </p>
      )}

      <div className="grid grid-cols-2 gap-2" role="group" aria-label="Forma de exibir as respostas">
        <button type="button" onClick={() => setModo("data")} aria-pressed={modo === "data"}
                className={classesBotao(modo === "data" ? "primario" : "secundario")}>Por data</button>
        <button type="button" onClick={() => setModo("tabela")} aria-pressed={modo === "tabela"}
                className={classesBotao(modo === "tabela" ? "primario" : "secundario")}>Tabela</button>
      </div>

      <div className={classeData}><VisaoPorData grade={grade} /></div>
      <div className={classeTabela}><TabelaDisponibilidade grade={grade} /></div>

      {grade.participantes.some((p) => p.observacao) && (
        <div className="flex flex-col gap-2 md:hidden">
          <h3 className="text-base font-semibold">Observações</h3>
          <ul className="flex flex-col gap-2">
            {grade.participantes.filter((p) => p.observacao).map((p) => (
              <li key={p.perfil_id} className="rounded-lg bg-slate-50 p-3 text-base">
                <span className="font-semibold">{p.nome}:</span> “{p.observacao}”
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}
