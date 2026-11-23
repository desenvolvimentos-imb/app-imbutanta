"use client";
// Publica o rascunho (FR-011): participantes passam a ver a escala. Pode ter vagas em aberto.
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { publicarEscala } from "@/app/(app)/ministerios/[id]/escalas/acoes";

export function PublicarEscala({ ministerioId, escalaId, vagasEmAberto }: { ministerioId: string; escalaId: string; vagasEmAberto: number }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(publicarEscala, {});
  return (
    <form action={acao} className="flex flex-col gap-3">
      <MensagemErro texto={estado.erro} />
      <input type="hidden" name="ministerio" value={ministerioId} />
      <input type="hidden" name="escala" value={escalaId} />
      {vagasEmAberto > 0 && (
        <p className="text-base text-slate-800">
          {vagasEmAberto === 1 ? "Há 1 vaga em aberto" : `Há ${vagasEmAberto} vagas em aberto`}: ela aparecerá como &quot;Em aberto&quot; para os participantes.
        </p>
      )}
      <BotaoEnviar>Publicar escala</BotaoEnviar>
    </form>
  );
}
