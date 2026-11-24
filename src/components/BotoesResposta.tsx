"use client";
// Confirmar ou recusar a participação, direto no item (FR-026). A recusa pede um motivo opcional.
// A resposta vale para todas as vagas da pessoa na escala e pode ser mudada até o início do evento.
import { useActionState, useState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { classesBotao } from "@/components/estilos-botao";
import { MensagemErro } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { RespostaEscala } from "@/lib/escalas/consultas";
import { responderEscala } from "@/app/(app)/minhas-escalas/acoes";

type Props = {
  escalaId: string;
  ministerioId: string;
  /** Nome do evento, para os rótulos acessíveis ("Confirmar presença: Culto"). */
  evento: string;
  atual: RespostaEscala;
};

export function BotoesResposta({ escalaId, ministerioId, evento, atual }: Props) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(responderEscala, {});
  const [recusando, setRecusando] = useState(false);

  const campos = (
    <>
      <input type="hidden" name="escala" value={escalaId} />
      <input type="hidden" name="ministerio" value={ministerioId} />
    </>
  );

  if (recusando) {
    return (
      <form action={acao} className="flex flex-col gap-3 rounded-lg border border-red-800 bg-red-50 p-3">
        {campos}
        <input type="hidden" name="resposta" value="recusado" />
        <MensagemErro texto={estado.erro} />
        <div className="flex flex-col gap-1">
          <label htmlFor={`motivo-${escalaId}`} className="text-base font-medium">Motivo (opcional)</label>
          <textarea id={`motivo-${escalaId}`} name="motivo" maxLength={200} rows={2}
                    aria-describedby={estado.erros?.motivo ? `motivo-${escalaId}-erro` : undefined}
                    className="rounded-lg border border-slate-500 bg-white px-3 py-2 text-base" />
          {estado.erros?.motivo && <p id={`motivo-${escalaId}-erro`} className="text-sm font-medium text-red-800">{estado.erros.motivo}</p>}
        </div>
        <BotaoEnviar variante="perigo" aria-label={`Confirmar recusa: ${evento}`}>Confirmar recusa</BotaoEnviar>
        <button type="button" onClick={() => setRecusando(false)} className={classesBotao("secundario")}>Voltar</button>
      </form>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <MensagemErro texto={estado.erro} />
      <div className="grid grid-cols-2 gap-2">
        <form action={acao}>
          {campos}
          <input type="hidden" name="resposta" value="confirmado" />
          <BotaoEnviar variante={atual === "confirmado" ? "secundario" : "primario"} aria-label={atual === "confirmado" ? `Confirmado: ${evento}` : `Confirmar presença: ${evento}`}
                       aria-pressed={atual === "confirmado"} disabled={atual === "confirmado"}>
            {atual === "confirmado" ? "Confirmado" : "Confirmar"}
          </BotaoEnviar>
        </form>
        <button type="button" onClick={() => setRecusando(true)} aria-label={atual === "recusado" ? `Mudar recusa: ${evento}` : `Recusar: ${evento}`}
                className={classesBotao("secundario")}>
          {atual === "recusado" ? "Mudar recusa" : "Recusar"}
        </button>
      </div>
    </div>
  );
}
