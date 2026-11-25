"use client";
// Escolha das datas de uma consulta (RF-002, RF-003): data a data, ou o atalho "todos os <dia da
// semana> de <mês>". As datas escolhidas ficam numa lista editável (com rótulo opcional) e seguem
// para a ação do servidor num campo escondido (JSON). Usa o campo de data do próprio navegador:
// sem biblioteca de calendário (constitution II).
import { useState } from "react";
import { classesBotao } from "@/components/estilos-botao";
import { DIAS_DA_SEMANA, datasDoDiaDaSemana, formatarDataConsulta } from "@/lib/disponibilidade/datas";
import { MAX_DATAS_POR_CONSULTA, type DataDaConsulta } from "@/lib/disponibilidade/validacao";

type Props = {
  /** "Hoje" em São Paulo (AAAA-MM-DD), calculado no servidor: nenhuma data anterior é aceita. */
  hoje: string;
  inicial?: DataDaConsulta[];
  /** Quantas datas a consulta já tem (ao adicionar a uma consulta existente), para o limite de 31. */
  jaExistentes?: number;
};

export function SeletorDatas({ hoje, inicial = [], jaExistentes = 0 }: Props) {
  const [lista, setLista] = useState<DataDaConsulta[]>(inicial);
  const [dataNova, setDataNova] = useState("");
  const [mes, setMes] = useState(hoje.slice(0, 7));
  const [diaDaSemana, setDiaDaSemana] = useState(0);
  const [aviso, setAviso] = useState("");

  const limite = MAX_DATAS_POR_CONSULTA - jaExistentes;

  function incluir(novas: string[]) {
    const existentes = new Set(lista.map((d) => d.data));
    const aceitas = novas.filter((d) => !existentes.has(d));
    if (lista.length + aceitas.length > limite) {
      setAviso(`Uma consulta pode ter no máximo ${MAX_DATAS_POR_CONSULTA} datas.`);
      return;
    }
    setAviso(novas.length > 0 && aceitas.length === 0 ? "Essas datas já estão na lista." : "");
    setLista((atual) =>
      [...atual, ...aceitas.map((data) => ({ data, rotulo: "" }))].sort((a, b) => a.data.localeCompare(b.data)),
    );
  }

  function adicionarUma() {
    if (!dataNova) return setAviso("Escolha uma data.");
    if (dataNova < hoje) return setAviso("A data não pode ser anterior a hoje.");
    incluir([dataNova]);
    setDataNova("");
  }

  function adicionarDoMes() {
    const [ano, m] = mes.split("-").map(Number);
    if (!ano || !m) return setAviso("Escolha o mês.");
    const datas = datasDoDiaDaSemana(ano, m, diaDaSemana, hoje);
    if (datas.length === 0) return setAviso("Não há datas desse dia da semana neste mês a partir de hoje.");
    incluir(datas);
  }

  const nomeMes = (() => {
    const [ano, m] = mes.split("-").map(Number);
    if (!ano || !m) return "o mês";
    return new Date(Date.UTC(ano, m - 1, 1)).toLocaleDateString("pt-BR", { month: "long", timeZone: "UTC" });
  })();

  return (
    <fieldset className="min-w-0 flex flex-col gap-4 rounded-lg border border-slate-400 p-4">
      <legend className="px-1 text-base font-semibold">Datas da consulta</legend>
      <input type="hidden" name="datas" value={JSON.stringify(lista)} />

      <div className="flex flex-col gap-2">
        <label htmlFor="nova-data" className="text-base font-medium">Escolher uma data</label>
        <div className="flex gap-2">
          <input id="nova-data" type="date" min={hoje} value={dataNova} onChange={(e) => setDataNova(e.target.value)}
                 className="min-h-12 min-w-0 flex-1 rounded-lg border border-slate-500 bg-white px-3 text-base" />
          <button type="button" onClick={adicionarUma} className={`${classesBotao("secundario")} !w-auto`}>
            Adicionar data
          </button>
        </div>
      </div>

      <div className="flex flex-col gap-2 border-t border-slate-300 pt-3">
        <p className="text-base font-medium">Ou todos os dias da semana de um mês</p>
        <div className="grid grid-cols-2 gap-2">
          <div className="flex min-w-0 flex-col gap-1">
            <label htmlFor="atalho-mes" className="text-sm text-slate-800">Mês</label>
            <input id="atalho-mes" type="month" value={mes} min={hoje.slice(0, 7)} onChange={(e) => setMes(e.target.value)}
                   className="min-h-12 w-full min-w-0 rounded-lg border border-slate-500 bg-white px-3 text-base" />
          </div>
          <div className="flex min-w-0 flex-col gap-1">
            <label htmlFor="atalho-dia" className="text-sm text-slate-800">Dia da semana</label>
            <select id="atalho-dia" value={diaDaSemana} onChange={(e) => setDiaDaSemana(Number(e.target.value))}
                    className="min-h-12 w-full min-w-0 rounded-lg border border-slate-500 bg-white px-3 text-base">
              {DIAS_DA_SEMANA.map((nome, i) => <option key={nome} value={i}>{nome}</option>)}
            </select>
          </div>
        </div>
        <button type="button" onClick={adicionarDoMes} className={classesBotao("secundario")}>
          Adicionar todos os dias ({DIAS_DA_SEMANA[diaDaSemana]}) de {nomeMes}
        </button>
      </div>

      {aviso && <p role="alert" className="text-base font-medium text-red-800">{aviso}</p>}

      <div>
        <p className="text-base font-medium" aria-live="polite">
          {lista.length} de {limite} datas
        </p>
        {lista.length === 0 ? (
          <p className="text-base text-slate-700">Nenhuma data escolhida ainda.</p>
        ) : (
          <ul className="mt-2 flex flex-col gap-2">
            {lista.map((d, i) => (
              <li key={d.data} className="flex flex-col gap-2 rounded-lg bg-slate-50 p-3">
                <p className="text-base font-semibold">{formatarDataConsulta(d.data)}</p>
                <div className="flex gap-2">
                  <label htmlFor={`rotulo-${d.data}`} className="sr-only">Rótulo de {formatarDataConsulta(d.data)}</label>
                  <input id={`rotulo-${d.data}`} type="text" maxLength={40} placeholder="Rótulo (opcional), ex.: Culto especial"
                         value={d.rotulo}
                         onChange={(e) => setLista((atual) => atual.map((x, j) => (j === i ? { ...x, rotulo: e.target.value } : x)))}
                         className="min-h-12 min-w-0 flex-1 rounded-lg border border-slate-500 bg-white px-3 text-base" />
                  <button type="button" onClick={() => setLista((atual) => atual.filter((_, j) => j !== i))}
                          aria-label={`Remover ${formatarDataConsulta(d.data)}`}
                          className={`${classesBotao("secundario")} !w-auto`}>
                    Remover
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </fieldset>
  );
}
