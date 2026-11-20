"use client";
// Lista de quem faz parte do ministério (nome e papel). Para quem pode gerir, mostra as ações
// de promover, rebaixar e remover. Esconder as ações NÃO é segurança: o banco barra de qualquer forma.
import { useActionState } from "react";
import { AcaoComConfirmacao } from "@/components/AcaoComConfirmacao";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { Participante } from "@/lib/ministerios/consultas";
import { alterarPapelNoMinisterio, removerParticipante } from "@/app/(app)/ministerios/[id]/actions";

const ROTULO_PAPEL = { lider: "Líder", participante: "Participante" } as const;

type Props = { ministerioId: string; participantes: Participante[]; podeGerir: boolean };

export function ListaParticipantes({ ministerioId, participantes, podeGerir }: Props) {
  const [estado, acaoPapel] = useActionState<EstadoForm, FormData>(alterarPapelNoMinisterio, {});

  if (participantes.length === 0) {
    return <p className="rounded-lg bg-slate-100 p-4 text-lg">Ninguém participa deste ministério ainda.</p>;
  }

  return (
    <>
      <MensagemErro texto={estado.erro} />
      <ul className="flex flex-col gap-3">
        {participantes.map((p) => {
          const ehLider = p.papel === "lider";
          return (
            <li key={p.perfil_id} className="flex flex-col gap-3 rounded-lg border border-slate-400 p-4">
              <div className="flex items-center justify-between gap-2">
                <p className="text-lg font-semibold">{p.nome}</p>
                <span
                  className={`rounded px-2 py-0.5 text-sm font-medium ${ehLider ? "bg-blue-100 text-blue-950" : "bg-slate-200 text-slate-800"}`}
                >
                  {ROTULO_PAPEL[p.papel]}
                </span>
              </div>

              {podeGerir && (
                <div className="grid gap-3">
                  <form action={acaoPapel}>
                    <input type="hidden" name="id" value={ministerioId} />
                    <input type="hidden" name="pessoa" value={p.perfil_id} />
                    <input type="hidden" name="papel" value={ehLider ? "participante" : "lider"} />
                    <BotaoEnviar
                      variante="secundario"
                      aria-label={ehLider ? `Rebaixar ${p.nome} a participante` : `Promover ${p.nome} a líder`}
                    >
                      {ehLider ? "Rebaixar" : "Promover"}
                    </BotaoEnviar>
                  </form>
                  <AcaoComConfirmacao
                    rotulo="Remover"
                    rotuloConfirmar="Confirmar remoção"
                    aviso={`${p.nome} deixa de participar deste ministério. A conta dela continua ativa.`}
                    acao={removerParticipante}
                    campos={{ id: ministerioId, pessoa: p.perfil_id }}
                    nomeAcessivel={`Remover ${p.nome}`}
                    nomeAcessivelConfirmar={`Confirmar remoção: ${p.nome}`}
                  />
                </div>
              )}
            </li>
          );
        })}
      </ul>
    </>
  );
}
