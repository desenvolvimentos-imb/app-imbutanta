"use client";
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { PedidoPendente } from "@/lib/ministerios/consultas";
import { decidirPedido } from "./actions";

// Data no formato brasileiro e fuso de São Paulo (constituição, restrições técnicas).
const formatarData = (iso: string) =>
  new Intl.DateTimeFormat("pt-BR", { dateStyle: "short", timeStyle: "short", timeZone: "America/Sao_Paulo" }).format(
    new Date(iso),
  );

export function PedidosDeEntrada({ pedidos }: { pedidos: PedidoPendente[] }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(decidirPedido, {});

  return (
    <>
      <MensagemErro texto={estado.erro} />
      {pedidos.length === 0 ? (
        <p className="rounded-lg bg-slate-100 p-4 text-lg">Nenhum pedido de entrada aguardando decisão.</p>
      ) : (
        <ul className="flex flex-col gap-4">
          {pedidos.map((p) => (
            <li key={p.pedido_id} className="flex flex-col gap-3 rounded-lg border border-slate-400 p-4">
              <div>
                <p className="text-lg font-semibold">{p.nome}</p>
                <p className="text-base">
                  Pediu para entrar em <span className="font-semibold">{p.ministerio_nome}</span>
                </p>
                <p className="text-sm text-slate-700">Pedido em {formatarData(p.criado_em)}</p>
                {p.conta_pendente && (
                  <p className="mt-1 rounded bg-blue-50 p-2 text-sm text-blue-950">
                    Conta nova: Aceitar também ativa a conta.
                  </p>
                )}
              </div>
              <div className="grid grid-cols-2 gap-3">
                {(["aceitar", "recusar"] as const).map((decisao) => (
                  <form key={decisao} action={acao}>
                    <input type="hidden" name="pedido" value={p.pedido_id} />
                    <input type="hidden" name="decisao" value={decisao} />
                    <BotaoEnviar
                      variante={decisao === "aceitar" ? "primario" : "secundario"}
                      aria-label={`${decisao === "aceitar" ? "Aceitar" : "Recusar"} ${p.nome} em ${p.ministerio_nome}`}
                    >
                      {decisao === "aceitar" ? "Aceitar" : "Recusar"}
                    </BotaoEnviar>
                  </form>
                ))}
              </div>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
