"use client";
import { useActionState } from "react";
import { Campo } from "@/components/Campo";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro, MensagemInfo } from "@/components/MensagemErro";
import { SeletorMinisterios } from "@/components/SeletorMinisterios";
import type { Ministerio } from "@/lib/ministerios/consultas";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { cadastrar } from "./actions";

export function FormularioCadastro({ ministerios }: { ministerios: Ministerio[] }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(cadastrar, {});

  if (estado.info) return <MensagemInfo texto={estado.info} />;

  return (
    <form action={acao} noValidate className="flex flex-col gap-4">
      <MensagemErro texto={estado.erro} />
      <Campo nome="nome" rotulo="Nome" autoComplete="name" erro={estado.erros?.nome} defaultValue={estado.valores?.nome} />
      <Campo nome="email" rotulo="Email" tipo="email" autoComplete="email" erro={estado.erros?.email} defaultValue={estado.valores?.email} />
      <Campo
        nome="senha"
        rotulo="Senha"
        tipo="password"
        autoComplete="new-password"
        dica="Pelo menos 8 caracteres, com letras e números."
        erro={estado.erros?.senha}
      />
      <SeletorMinisterios
        ministerios={ministerios}
        legenda="Ministérios de que você participa (opcional)"
        dica="Marcar é só um pedido: o líder de cada ministério decide se aceita."
      />
      <BotaoEnviar>Criar conta</BotaoEnviar>
    </form>
  );
}
