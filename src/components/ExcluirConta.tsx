"use client";
// Exclusão da própria conta, com confirmação explícita (RF-030). Fica recolhida dentro de
// um <details> para não ser acionada sem querer; desistir é só fechar.
import { useActionState } from "react";
import { excluirMinhaConta } from "@/app/actions/excluir-conta";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { BotaoEnviar } from "./Botao";
import { MensagemErro } from "./MensagemErro";

export function ExcluirConta() {
  const [estado, acao] = useActionState<EstadoForm, FormData>(excluirMinhaConta, {});

  return (
    <details className="rounded-lg border border-red-800 p-4" open={Boolean(estado.erro)}>
      <summary className="min-h-12 cursor-pointer py-2 text-lg font-semibold text-red-900">
        Excluir minha conta
      </summary>
      <form action={acao} noValidate className="mt-3 flex flex-col gap-4">
        <p>
          Isto apaga a sua conta e os seus dados pessoais (nome e email) do app, junto com os seus
          vínculos e pedidos de ministério.{" "}
          <strong>Não dá para desfazer.</strong> Se quiser voltar depois, será preciso criar uma
          nova conta e aguardar aprovação.
        </p>
        <MensagemErro texto={estado.erro} />
        <div className="flex flex-col gap-1">
          <label htmlFor="confirmacao" className="text-base font-medium">
            Digite EXCLUIR para confirmar
          </label>
          <input
            id="confirmacao"
            name="confirmacao"
            type="text"
            autoComplete="off"
            autoCapitalize="characters"
            className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base focus:outline-3 focus:outline-offset-2 focus:outline-blue-700"
          />
        </div>
        <BotaoEnviar variante="perigo">Excluir definitivamente</BotaoEnviar>
        <p className="text-sm text-slate-700">Para desistir, é só fechar esta seção.</p>
      </form>
    </details>
  );
}
