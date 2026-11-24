"use client";
// Remove uma data de consulta aberta. Se ela já tem respostas, o banco não remove e devolve a
// contagem: o líder confirma, sabendo que as respostas serão descartadas (RF-010).
import { useActionState, useState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { classesBotao } from "@/components/estilos-botao";
import { MensagemErro } from "@/components/MensagemErro";
import { formatarDataConsulta } from "@/lib/disponibilidade/datas";
import type { EstadoRemocao } from "@/lib/disponibilidade/estado";

type Props = {
  acao: (anterior: EstadoRemocao, formData: FormData) => Promise<EstadoRemocao>;
  ministerioId: string;
  consultaId: string;
  dataId: string;
  data: string;
};

export function RemoverData({ acao, ministerioId, consultaId, dataId, data }: Props) {
  const [estado, executar] = useActionState<EstadoRemocao, FormData>(acao, {});
  const [dispensado, setDispensado] = useState(false);
  const confirmando = estado.confirmacao && !dispensado;
  const campos = (
    <>
      <input type="hidden" name="ministerio" value={ministerioId} />
      <input type="hidden" name="consulta" value={consultaId} />
      <input type="hidden" name="data" value={dataId} />
    </>
  );

  if (confirmando) {
    const n = estado.confirmacao!.respostas;
    return (
      <form action={executar} className="flex flex-col gap-3 rounded-lg border border-red-800 bg-red-50 p-3">
        {campos}
        <input type="hidden" name="confirmado" value="1" />
        <p role="alert" className="text-base text-red-950">
          {formatarDataConsulta(data)} tem {n} {n === 1 ? "resposta" : "respostas"}. Ao remover, elas serão descartadas. Remover mesmo assim?
        </p>
        <BotaoEnviar variante="perigo">Remover mesmo assim</BotaoEnviar>
        <button type="button" onClick={() => setDispensado(true)} className={classesBotao("secundario")}>Cancelar</button>
      </form>
    );
  }

  return (
    <form action={(f) => { setDispensado(false); executar(f); }} className="flex flex-col gap-2">
      {campos}
      <MensagemErro texto={estado.erro} />
      <BotaoEnviar variante="secundario" aria-label={`Remover ${formatarDataConsulta(data)}`}>Remover</BotaoEnviar>
    </form>
  );
}
