"use client";
// Botão de duas etapas para ações que afetam outras pessoas (desativar ministério, remover
// participante): o primeiro toque só pede a confirmação; o segundo executa (WCAG: sem surpresa).
import { useActionState, useState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { classesBotao } from "@/components/estilos-botao";
import { MensagemErro } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";

type Props = {
  /** Texto do primeiro botão, ex.: "Desativar ministério". */
  rotulo: string;
  /** Texto do botão que confirma, ex.: "Confirmar desativação". */
  rotuloConfirmar: string;
  /** Explica o que vai acontecer, mostrado na etapa de confirmação. */
  aviso: string;
  acao: (anterior: EstadoForm, formData: FormData) => Promise<EstadoForm>;
  /** Campos escondidos enviados à ação (ids). */
  campos: Record<string, string>;
  /** Nome acessível do primeiro botão quando há vários iguais na página (ex.: "Remover Ana"). */
  nomeAcessivel?: string;
  /** Nome acessível do botão que confirma (ex.: "Confirmar remoção: Ana"). Deve conter o texto visível. */
  nomeAcessivelConfirmar?: string;
  variante?: "primario" | "secundario" | "perigo";
};

export function AcaoComConfirmacao({
  rotulo,
  rotuloConfirmar,
  aviso,
  acao,
  campos,
  nomeAcessivel,
  nomeAcessivelConfirmar,
  variante = "perigo",
}: Props) {
  const [confirmando, setConfirmando] = useState(false);
  const [estado, executar] = useActionState<EstadoForm, FormData>(acao, {});

  if (!confirmando) {
    return (
      <div className="flex flex-col gap-2">
        <MensagemErro texto={estado.erro} />
        <button
          type="button"
          onClick={() => setConfirmando(true)}
          aria-label={nomeAcessivel}
          className={classesBotao("secundario")}
        >
          {rotulo}
        </button>
      </div>
    );
  }

  return (
    <form action={executar} className="flex flex-col gap-3 rounded-lg border border-red-800 bg-red-50 p-3">
      <p className="text-base text-red-950">{aviso}</p>
      {Object.entries(campos).map(([nome, valor]) => (
        <input key={nome} type="hidden" name={nome} value={valor} />
      ))}
      <BotaoEnviar variante={variante} aria-label={nomeAcessivelConfirmar}>
        {rotuloConfirmar}
      </BotaoEnviar>
      <button type="button" onClick={() => setConfirmando(false)} className={classesBotao("secundario")}>
        Cancelar
      </button>
    </form>
  );
}
