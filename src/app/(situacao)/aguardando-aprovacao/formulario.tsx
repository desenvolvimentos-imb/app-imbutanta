"use client";
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro } from "@/components/MensagemErro";
import { SeletorMinisterios } from "@/components/SeletorMinisterios";
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { Ministerio } from "@/lib/ministerios/consultas";
import { pedirMinisterios } from "./actions";

export function FormularioPedirMinisterios({ ministerios }: { ministerios: Ministerio[] }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(pedirMinisterios, {});
  if (ministerios.length === 0) return null;

  return (
    <form action={acao} className="flex flex-col gap-3 text-base">
      <MensagemErro texto={estado.erro} />
      <SeletorMinisterios
        ministerios={ministerios}
        legenda="Pedir para entrar em ministérios"
        dica="O líder de cada ministério decide. Se ele aceitar, a sua conta também é ativada."
      />
      <BotaoEnviar>Enviar pedidos</BotaoEnviar>
    </form>
  );
}
