"use client";
import { useActionState } from "react";
import { Campo } from "@/components/Campo";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro, MensagemInfo } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { pedirRecuperacao } from "./actions";

export function FormularioRecuperar({ erroInicial }: { erroInicial?: string }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(pedirRecuperacao, {});

  return (
    <form action={acao} noValidate className="flex flex-col gap-4">
      <MensagemErro texto={estado.erro ?? erroInicial} />
      <MensagemInfo texto={estado.info} />
      <Campo nome="email" rotulo="Email" tipo="email" autoComplete="email" erro={estado.erros?.email} defaultValue={estado.valores?.email} />
      <BotaoEnviar>Enviar link</BotaoEnviar>
    </form>
  );
}
