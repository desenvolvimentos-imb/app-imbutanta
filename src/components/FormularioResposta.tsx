"use client";
// O participante marca, por data, "Disponível", "Indisponível" ou "Sem resposta" (RF-016) e pode
// deixar uma observação de até 300 caracteres (RF-018). Salva respostas parciais; consulta fechada
// aparece só para leitura. Cada data é um grupo de botões de opção (teclado e leitor de tela).
import { useActionState, useState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro, MensagemInfo } from "@/components/MensagemErro";
import { formatarDataConsulta } from "@/lib/disponibilidade/datas";
import type { ConsultaParaResponder } from "@/lib/disponibilidade/consultas";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { MAX_OBSERVACAO } from "@/lib/disponibilidade/validacao";

type Props = {
  consulta: ConsultaParaResponder;
  acao: (anterior: EstadoForm, formData: FormData) => Promise<EstadoForm>;
};

const OPCOES = [
  { valor: "disponivel", rotulo: "Disponível", icone: "✓" },
  { valor: "indisponivel", rotulo: "Indisponível", icone: "✕" },
  { valor: "", rotulo: "Sem resposta", icone: "?" },
] as const;

export function FormularioResposta({ consulta, acao }: Props) {
  const [estado, executar] = useActionState<EstadoForm, FormData>(acao, {});
  const [observacao, setObservacao] = useState(consulta.observacao);
  const somenteLeitura = !consulta.pode_responder;
  // Recria o formulário quando o servidor devolve novos valores: o React limpa os campos depois de
  // cada ação, e assim as opções refletem o que ficou salvo.
  const chave = JSON.stringify([consulta.datas.map((d) => d.resposta), consulta.observacao]);

  return (
    <form action={executar} className="flex flex-col gap-4" key={chave}>
      <MensagemErro texto={estado.erro} />
      <MensagemInfo texto={estado.info} />
      <input type="hidden" name="consulta" value={consulta.id} />

      {consulta.datas.map((d) => {
        const bloqueada = somenteLeitura || d.passada;
        const atual = d.resposta ?? "";
        return (
          <fieldset key={d.id} disabled={bloqueada} className="flex flex-col gap-2 rounded-lg border border-slate-400 p-3">
            <legend className="px-1 text-lg font-semibold">
              {formatarDataConsulta(d.data)}
              {d.rotulo && <span className="font-normal text-slate-800"> · {d.rotulo}</span>}
            </legend>
            {!bloqueada && <input type="hidden" name="datas_ids" value={d.id} />}
            {d.passada && <p className="text-base text-slate-700">Esta data já passou.</p>}
            <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
              {OPCOES.map((o) => (
                <label key={o.rotulo}
                       className="flex min-h-12 cursor-pointer items-center gap-2 rounded-lg border border-slate-500 px-3 text-base has-[:checked]:border-blue-900 has-[:checked]:bg-blue-50 has-[:checked]:font-semibold has-[:disabled]:opacity-70">
                  <input type="radio" name={`resp_${d.id}`} value={o.valor} defaultChecked={atual === o.valor} className="size-5" />
                  <span aria-hidden="true">{o.icone}</span>
                  {o.rotulo}
                </label>
              ))}
            </div>
          </fieldset>
        );
      })}

      <div className="flex flex-col gap-1">
        <label htmlFor="observacao" className="text-base font-medium">Observação para o líder (opcional)</label>
        <textarea id="observacao" name="observacao" rows={3} maxLength={MAX_OBSERVACAO} value={observacao}
                  onChange={(e) => setObservacao(e.target.value)} disabled={somenteLeitura}
                  aria-describedby="observacao-contador"
                  className="rounded-lg border border-slate-500 bg-white px-3 py-2 text-base disabled:bg-slate-100" />
        <p id="observacao-contador" className="text-sm text-slate-700">
          {observacao.length} de {MAX_OBSERVACAO} caracteres. Só o líder e os administradores veem.
        </p>
        {estado.erros?.observacao && <p className="text-sm font-medium text-red-800">{estado.erros.observacao}</p>}
      </div>

      {!somenteLeitura && <BotaoEnviar>Salvar respostas</BotaoEnviar>}
    </form>
  );
}
