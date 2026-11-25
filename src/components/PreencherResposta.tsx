"use client";
// O líder preenche ou corrige as respostas de um participante, também com a consulta fechada
// (RF-021). Uma pessoa por bloco; usa as mesmas opções da tela do participante.
import { useActionState, useEffect, useRef } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro, MensagemInfo } from "@/components/MensagemErro";
import { formatarDataConsulta } from "@/lib/disponibilidade/datas";
import type { DataDaGrade, LinhaDaGrade } from "@/lib/disponibilidade/consultas";
import type { EstadoForm } from "@/lib/auth/estado-form";

type Props = {
  acao: (anterior: EstadoForm, formData: FormData) => Promise<EstadoForm>;
  ministerioId: string;
  consultaId: string;
  datas: DataDaGrade[];
  pessoa: LinhaDaGrade;
};

const OPCOES = [
  { valor: "disponivel", rotulo: "Disponível", icone: "✓" },
  { valor: "indisponivel", rotulo: "Indisponível", icone: "✕" },
  { valor: "", rotulo: "Sem resposta", icone: "?" },
] as const;

export function PreencherResposta({ acao, ministerioId, consultaId, datas, pessoa }: Props) {
  const [estado, executar] = useActionState<EstadoForm, FormData>(acao, {});
  const detalhes = useRef<HTMLDetailsElement>(null);
  // O link "Corrigir" da grade aponta para #corrigir-<pessoa>: abre o bloco e leva até ele.
  useEffect(() => {
    const abrirSeForEste = () => {
      if (window.location.hash === `#corrigir-${pessoa.perfil_id}` && detalhes.current) {
        detalhes.current.open = true;
        detalhes.current.scrollIntoView({ block: "start" });
      }
    };
    abrirSeForEste();
    window.addEventListener("hashchange", abrirSeForEste);
    return () => window.removeEventListener("hashchange", abrirSeForEste);
  }, [pessoa.perfil_id]);
  const chave = JSON.stringify(Object.entries(pessoa.respostas).map(([id, r]) => [id, r.resposta, r.preenchida_pelo_lider]));
  return (
    <details ref={detalhes} id={`corrigir-${pessoa.perfil_id}`} className="rounded-lg border border-slate-400 p-3">
      <summary className="min-h-12 cursor-pointer text-base font-semibold leading-12">Preencher ou corrigir: {pessoa.nome}</summary>
      <form action={executar} className="mt-3 flex flex-col gap-3" key={chave}>
        <MensagemErro texto={estado.erro} />
        <MensagemInfo texto={estado.info} />
        <input type="hidden" name="ministerio" value={ministerioId} />
        <input type="hidden" name="consulta" value={consultaId} />
        <input type="hidden" name="perfil" value={pessoa.perfil_id} />
        {datas.map((d) => (
          <fieldset key={d.id} className="flex flex-col gap-2">
            <legend className="text-base font-medium">
              {formatarDataConsulta(d.data)}{d.rotulo && ` · ${d.rotulo}`}
            </legend>
            <input type="hidden" name="datas_ids" value={d.id} />
            <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
              {OPCOES.map((o) => (
                <label key={o.rotulo}
                       className="flex min-h-12 cursor-pointer items-center gap-2 rounded-lg border border-slate-500 px-3 text-base has-[:checked]:border-blue-900 has-[:checked]:bg-blue-50 has-[:checked]:font-semibold">
                  <input type="radio" name={`resp_${d.id}`} value={o.valor} defaultChecked={(pessoa.respostas[d.id]?.resposta ?? "") === o.valor} className="size-5" />
                  <span aria-hidden="true">{o.icone}</span>
                  {o.rotulo}
                </label>
              ))}
            </div>
          </fieldset>
        ))}
        <BotaoEnviar>Salvar respostas de {pessoa.nome}</BotaoEnviar>
      </form>
    </details>
  );
}
