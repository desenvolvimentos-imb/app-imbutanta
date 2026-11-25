"use client";
// Formulário de consulta: título, mensagem e prazo; ao criar, também as datas. Serve para criar e
// para editar (na edição as datas são geridas à parte, na própria tela da consulta).
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { Campo } from "@/components/Campo";
import { MensagemErro, MensagemInfo } from "@/components/MensagemErro";
import { SeletorDatas } from "@/components/SeletorDatas";
import type { EstadoForm } from "@/lib/auth/estado-form";

type Props = {
  acao: (anterior: EstadoForm, formData: FormData) => Promise<EstadoForm>;
  ministerioId: string;
  hoje: string;
  /** Presente ao editar. */
  consultaId?: string;
  inicial?: { titulo: string; mensagem: string; prazo: string | null };
  rotuloBotao: string;
};

export function FormularioConsulta({ acao, ministerioId, hoje, consultaId, inicial, rotuloBotao }: Props) {
  const [estado, executar] = useActionState<EstadoForm, FormData>(acao, {});
  const v = estado.valores ?? (inicial ? { titulo: inicial.titulo, mensagem: inicial.mensagem, prazo: inicial.prazo ?? "" } : undefined);
  const chave = consultaId ? JSON.stringify(inicial) : "nova";
  return (
    <form action={executar} noValidate className="flex flex-col gap-4" key={chave + (estado.info ?? "")}>
      <MensagemErro texto={estado.erro} />
      <MensagemInfo texto={estado.info} />
      <input type="hidden" name="ministerio" value={ministerioId} />
      {consultaId && <input type="hidden" name="consulta" value={consultaId} />}
      <Campo nome="titulo" rotulo="Título" dica='Ex.: "Escala de dezembro"' erro={estado.erros?.titulo} defaultValue={v?.titulo} maxLength={80} />
      <div className="flex flex-col gap-1">
        <label htmlFor="mensagem" className="text-base font-medium text-slate-900">Mensagem para os participantes (opcional)</label>
        <textarea id="mensagem" name="mensagem" rows={3} maxLength={500} defaultValue={v?.mensagem}
                  className="rounded-lg border border-slate-500 bg-white px-3 py-2 text-base" />
      </div>
      <div className="flex flex-col gap-1">
        <label htmlFor="prazo" className="text-base font-medium text-slate-900">Prazo para responder (opcional)</label>
        <input id="prazo" name="prazo" type="date" min={hoje} defaultValue={v?.prazo}
               aria-describedby="prazo-dica"
               className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base" />
        <p id="prazo-dica" className="text-sm text-slate-700">A consulta fecha sozinha ao fim desse dia.</p>
      </div>
      {!consultaId && <SeletorDatas hoje={hoje} />}
      <BotaoEnviar>{rotuloBotao}</BotaoEnviar>
    </form>
  );
}
