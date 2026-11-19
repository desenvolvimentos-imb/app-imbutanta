"use client";
import { useActionState } from "react";
import { Campo } from "@/components/Campo";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { redefinirSenha } from "./actions";

export function FormularioRedefinir() {
  const [estado, acao] = useActionState<EstadoForm, FormData>(redefinirSenha, {});
  return (
    <form action={acao} noValidate className="flex flex-col gap-4">
      <MensagemErro texto={estado.erro} />
      <Campo
        nome="senha"
        rotulo="Nova senha"
        tipo="password"
        autoComplete="new-password"
        dica="Pelo menos 8 caracteres, com letras e números."
        erro={estado.erros?.senha}
      />
      <Campo nome="confirmacao" rotulo="Repita a nova senha" tipo="password" autoComplete="new-password" erro={estado.erros?.confirmacao} />
      <BotaoEnviar>Salvar nova senha</BotaoEnviar>
    </form>
  );
}
