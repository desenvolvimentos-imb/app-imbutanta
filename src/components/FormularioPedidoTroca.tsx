"use client";
// Pedir troca de uma vaga: a pessoa escolhe quem a assume, numa lista de participantes que ainda não
// estão na escala (sem digitar email). Nada muda na escala até o líder aprovar (FR-029, FR-031).
import { useActionState, useState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { classesBotao } from "@/components/estilos-botao";
import { MensagemErro, MensagemInfo } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { Candidata } from "@/lib/escalas/consultas";
import { pedirTroca } from "@/app/(app)/pedidos-de-troca/acoes";

type Props = {
  vagaId: string;
  escalaId: string;
  ministerioId: string;
  /** Nome da vaga para os rótulos acessíveis, ex.: "Vocal · Vocal 1". */
  nomeVaga: string;
  candidatas: Candidata[];
};

export function FormularioPedidoTroca({ vagaId, escalaId, ministerioId, nomeVaga, candidatas }: Props) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(pedirTroca, {});
  const [aberto, setAberto] = useState(false);

  if (candidatas.length === 0) {
    return <p className="text-base text-slate-800">Não há outra pessoa do ministério disponível para assumir esta vaga.</p>;
  }
  if (!aberto) {
    return (
      <button type="button" onClick={() => setAberto(true)} aria-label={`Pedir troca da vaga ${nomeVaga}`} className={classesBotao("secundario")}>
        Pedir troca
      </button>
    );
  }
  return (
    <form action={acao} noValidate className="flex flex-col gap-3 rounded-lg border border-slate-400 p-3">
      <MensagemErro texto={estado.erro} />
      <MensagemInfo texto={estado.info} />
      <input type="hidden" name="vaga" value={vagaId} />
      <input type="hidden" name="escala" value={escalaId} />
      <input type="hidden" name="ministerio" value={ministerioId} />
      <div className="flex flex-col gap-1">
        <label htmlFor={`indicada-${vagaId}`} className="text-base font-medium">Quem vai assumir a vaga</label>
        <select id={`indicada-${vagaId}`} name="indicada" defaultValue=""
                aria-describedby={estado.erros?.indicada ? `indicada-${vagaId}-erro` : undefined}
                className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base">
          <option value="" disabled>Escolha uma pessoa</option>
          {candidatas.map((c) => <option key={c.id} value={c.id}>{c.nome}</option>)}
        </select>
        {estado.erros?.indicada && <p id={`indicada-${vagaId}-erro`} className="text-sm font-medium text-red-800">{estado.erros.indicada}</p>}
      </div>
      <BotaoEnviar aria-label={`Enviar pedido de troca da vaga ${nomeVaga}`}>Enviar pedido</BotaoEnviar>
      <button type="button" onClick={() => setAberto(false)} className={classesBotao("secundario")}>Voltar</button>
    </form>
  );
}
