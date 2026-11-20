"use client";
// Botões de pedido de entrada em ministério: pedir e cancelar o próprio pedido pendente.
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { cancelarPedido, pedirEntrada } from "@/app/(app)/meus-ministerios/actions";

export function BotaoPedirEntrada({ ministerioId, nome }: { ministerioId: string; nome: string }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(pedirEntrada, {});
  return (
    <form action={acao} className="flex flex-col gap-2">
      <MensagemErro texto={estado.erro} />
      <input type="hidden" name="ministerio" value={ministerioId} />
      <BotaoEnviar aria-label={`Pedir para entrar em ${nome}`}>Pedir para entrar</BotaoEnviar>
    </form>
  );
}

export function BotaoCancelarPedido({ pedidoId, ministerioId, nome }: { pedidoId: string; ministerioId: string; nome: string }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(cancelarPedido, {});
  return (
    <form action={acao} className="flex flex-col gap-2">
      <MensagemErro texto={estado.erro} />
      <input type="hidden" name="pedido" value={pedidoId} />
      <input type="hidden" name="ministerio" value={ministerioId} />
      <BotaoEnviar variante="secundario" aria-label={`Cancelar pedido de ${nome}`}>
        Cancelar pedido
      </BotaoEnviar>
    </form>
  );
}
