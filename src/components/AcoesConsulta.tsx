"use client";
// Fechar e reabrir a consulta. Reabrir com prazo vencido pede um novo prazo ou a remoção do prazo
// (RF-008); sem prazo vencido, é um toque.
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro, MensagemInfo } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";

type Acao = (anterior: EstadoForm, formData: FormData) => Promise<EstadoForm>;

type Props = {
  ministerioId: string;
  consultaId: string;
  aberta: boolean;
  prazoVencido: boolean;
  hoje: string;
  fechar: Acao;
  reabrir: Acao;
};

export function AcoesConsulta({ ministerioId, consultaId, aberta, prazoVencido, hoje, fechar, reabrir }: Props) {
  const [estadoFechar, executarFechar] = useActionState<EstadoForm, FormData>(fechar, {});
  const [estadoReabrir, executarReabrir] = useActionState<EstadoForm, FormData>(reabrir, {});
  const campos = (
    <>
      <input type="hidden" name="ministerio" value={ministerioId} />
      <input type="hidden" name="consulta" value={consultaId} />
    </>
  );

  if (aberta) {
    return (
      <form action={executarFechar} className="flex flex-col gap-3">
        <MensagemErro texto={estadoFechar.erro} />
        {campos}
        <BotaoEnviar variante="secundario">Fechar consulta</BotaoEnviar>
      </form>
    );
  }

  return (
    <form action={executarReabrir} className="flex flex-col gap-3">
      <MensagemErro texto={estadoReabrir.erro} />
      <MensagemInfo texto={estadoReabrir.info} />
      {campos}
      {prazoVencido && (
        <fieldset className="min-w-0 flex flex-col gap-3 rounded-lg border border-amber-800 bg-amber-50 p-3">
          <legend className="px-1 text-base font-semibold text-amber-950">O prazo desta consulta já passou</legend>
          <div className="flex flex-col gap-1">
            <label htmlFor="novo_prazo" className="text-base font-medium">Novo prazo</label>
            <input id="novo_prazo" name="novo_prazo" type="date" min={hoje}
                   className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base" />
          </div>
          <label className="flex min-h-12 items-center gap-3 text-base">
            <input type="checkbox" name="remover_prazo" value="1" className="size-6" />
            Reabrir sem prazo
          </label>
        </fieldset>
      )}
      <BotaoEnviar>Reabrir consulta</BotaoEnviar>
    </form>
  );
}
