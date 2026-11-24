"use client";
// Formulário de escala: evento, data, horário e observação. Serve para criar e para editar.
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { Campo } from "@/components/Campo";
import { MensagemErro, MensagemInfo } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";

type Props = {
  acao: (anterior: EstadoForm, formData: FormData) => Promise<EstadoForm>;
  ministerioId: string;
  /** Presente ao editar. */
  escalaId?: string;
  inicial?: { evento: string; data: string; horario: string; observacao: string };
  rotuloBotao: string;
  /** Aviso mostrado ao editar uma escala publicada: mudar data ou horário zera as respostas. */
  avisoRespostas?: boolean;
};

export function FormularioEscala({ acao, ministerioId, escalaId, inicial, rotuloBotao, avisoRespostas }: Props) {
  const [estado, executar] = useActionState<EstadoForm, FormData>(acao, {});
  const v = estado.valores ?? inicial;
  return (
    <form action={executar} noValidate className="flex flex-col gap-4">
      <MensagemErro texto={estado.erro} />
      <MensagemInfo texto={estado.info} />
      <input type="hidden" name="ministerio" value={ministerioId} />
      {escalaId && <input type="hidden" name="escala" value={escalaId} />}
      <Campo nome="evento" rotulo="Nome do evento" erro={estado.erros?.evento} defaultValue={v?.evento} maxLength={80} />
      <div className="grid grid-cols-2 gap-3">
        <div className="flex flex-col gap-1">
          <label htmlFor="data" className="text-base font-medium text-slate-900">Data</label>
          <input id="data" name="data" type="date" required defaultValue={v?.data}
                 aria-invalid={estado.erros?.data ? true : undefined} aria-describedby={estado.erros?.data ? "data-erro" : undefined}
                 className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base" />
          {estado.erros?.data && <p id="data-erro" className="text-sm font-medium text-red-800">{estado.erros.data}</p>}
        </div>
        <div className="flex flex-col gap-1">
          <label htmlFor="horario" className="text-base font-medium text-slate-900">Horário de início</label>
          <input id="horario" name="horario" type="time" required defaultValue={v?.horario?.slice(0, 5)}
                 aria-invalid={estado.erros?.horario ? true : undefined} aria-describedby={estado.erros?.horario ? "horario-erro" : undefined}
                 className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base" />
          {estado.erros?.horario && <p id="horario-erro" className="text-sm font-medium text-red-800">{estado.erros.horario}</p>}
        </div>
      </div>
      <Campo nome="observacao" rotulo="Observação" obrigatorio={false} erro={estado.erros?.observacao}
             defaultValue={v?.observacao} maxLength={300} />
      {avisoRespostas && (
        <p className="text-base text-slate-800">
          Se você mudar a data ou o horário, as respostas de todos voltam para &quot;pendente&quot; e os pedidos de troca em andamento são cancelados.
        </p>
      )}
      <BotaoEnviar>{rotuloBotao}</BotaoEnviar>
    </form>
  );
}
