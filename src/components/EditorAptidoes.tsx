"use client";
// Aptidões: em quais funções cada participante é apto, principal ou secundária (FR-004). Nesta
// funcionalidade as duas contam igual como "apto"; a diferença é só informação para o líder.
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro, MensagemInfo } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { AptidaoDaPessoa, FuncaoMinisterio } from "@/lib/escalas/consultas";
import type { Participante } from "@/lib/ministerios/consultas";
import { salvarAptidoes } from "@/app/(app)/ministerios/[id]/funcoes/acoes";

type Props = {
  ministerioId: string;
  participantes: Participante[];
  /** Todas as funções, inclusive desativadas (uma desativada só aparece para quem já a tinha). */
  funcoes: FuncaoMinisterio[];
  aptidoes: AptidaoDaPessoa[];
};

function FormularioDaPessoa({ ministerioId, pessoa, funcoes, aptidoes }: {
  ministerioId: string; pessoa: Participante; funcoes: FuncaoMinisterio[]; aptidoes: AptidaoDaPessoa[];
}) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(salvarAptidoes, {});
  const tipoDe = (funcaoId: string) => aptidoes.find((a) => a.funcao_id === funcaoId)?.tipo ?? "";
  // Função desativada só é mostrada se a pessoa já a tinha (não dá para adicionar nova).
  const visiveis = funcoes.filter((f) => f.ativa || tipoDe(f.id) !== "");

  return (
    <li className="rounded-lg border border-slate-400 p-4">
      <form action={acao} className="flex flex-col gap-3">
        <h3 className="text-lg font-semibold">{pessoa.nome}</h3>
        <MensagemErro texto={estado.erro} />
        <MensagemInfo texto={estado.info} />
        <input type="hidden" name="ministerio" value={ministerioId} />
        <input type="hidden" name="pessoa" value={pessoa.perfil_id} />
        {visiveis.length === 0 ? (
          <p className="text-base text-slate-800">Crie funções acima para cadastrar aptidões.</p>
        ) : (
          visiveis.map((f) => {
            const id = `apto-${pessoa.perfil_id}-${f.id}`;
            return (
              <div key={f.id} className="flex flex-col gap-1">
                <label htmlFor={id} className="text-base font-medium">
                  {f.nome}
                  {!f.ativa && <span className="font-normal text-slate-700"> (desativada)</span>}
                </label>
                <select id={id} name={`apto-${f.id}`} defaultValue={tipoDe(f.id)}
                        className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base">
                  <option value="">Não é apto</option>
                  <option value="principal">Apto, função principal</option>
                  <option value="secundaria">Apto, função secundária</option>
                </select>
              </div>
            );
          })
        )}
        {visiveis.length > 0 && (
          <BotaoEnviar variante="secundario" aria-label={`Salvar aptidões de ${pessoa.nome}`}>Salvar aptidões</BotaoEnviar>
        )}
      </form>
    </li>
  );
}

export function EditorAptidoes({ ministerioId, participantes, funcoes, aptidoes }: Props) {
  if (participantes.length === 0) {
    return <p className="rounded-lg bg-slate-100 p-4 text-lg">Ninguém participa deste ministério ainda.</p>;
  }
  return (
    <ul className="flex flex-col gap-3">
      {participantes.map((p) => (
        <FormularioDaPessoa key={p.perfil_id} ministerioId={ministerioId} pessoa={p} funcoes={funcoes}
                            aptidoes={aptidoes.filter((a) => a.perfil_id === p.perfil_id)} />
      ))}
    </ul>
  );
}
