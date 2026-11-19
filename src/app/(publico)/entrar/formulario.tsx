"use client";
import { useActionState } from "react";
import { Campo } from "@/components/Campo";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { entrar } from "./actions";

export function FormularioEntrar({ voltar, erroInicial }: { voltar?: string; erroInicial?: string }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(entrar, {});

  return (
    <form action={acao} noValidate className="flex flex-col gap-4">
      <MensagemErro texto={estado.erro ?? erroInicial} />
      <input type="hidden" name="voltar" value={voltar ?? ""} />
      <Campo nome="email" rotulo="Email" tipo="email" autoComplete="email" defaultValue={estado.valores?.email} />
      <Campo nome="senha" rotulo="Senha" tipo="password" autoComplete="current-password" />
      <BotaoEnviar>Entrar</BotaoEnviar>
    </form>
  );
}
