"use client";
// Avisos ao líder antes de gravar uma vaga: não bloqueiam, mas pedem confirmação (FR-017, FR-018).
// "Continuar mesmo assim" reenvia o formulário com `ciente` (definido por `aoContinuar`); "Escolher outra pessoa" só fecha o aviso.
import { BotaoEnviar } from "@/components/Botao";
import { classesBotao } from "@/components/estilos-botao";
import { textoDoAviso, type Aviso } from "@/lib/escalas/avisos";

type Props = {
  avisos: Aviso[];
  aoDispensar: () => void;
  /** Reenvia o MESMO formulário com a ciência do líder (o formulário acrescenta `ciente`). */
  aoContinuar: (formData: FormData) => void;
};

export function AvisosVaga({ avisos, aoDispensar, aoContinuar }: Props) {
  if (avisos.length === 0) return null;
  return (
    <div role="alert" className="flex flex-col gap-3 rounded-lg border border-amber-800 bg-amber-50 p-3 text-amber-950">
      <p className="text-base font-semibold">Atenção</p>
      <ul className="flex list-disc flex-col gap-1 pl-5 text-base">
        {avisos.map((a, i) => (
          <li key={i}>{textoDoAviso(a)}</li>
        ))}
      </ul>
      <p className="text-base">Você pode continuar mesmo assim.</p>
      <BotaoEnviar formAction={aoContinuar}>Continuar mesmo assim</BotaoEnviar>
      <button type="button" onClick={aoDispensar} className={classesBotao("secundario")}>
        Escolher outra pessoa
      </button>
    </div>
  );
}
