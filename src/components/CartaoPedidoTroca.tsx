"use client";
// Um pedido de troca com as ações que a pessoa pode fazer agora (FR-030, FR-031, FR-034, FR-036):
// a indicada aceita ou recusa; o líder aprova (com avisos) ou recusa; quem pediu e o líder cancelam.
import { useActionState, useState } from "react";
import Link from "next/link";
import { AvisosVaga } from "@/components/AvisosVaga";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro } from "@/components/MensagemErro";
import { SeloTroca } from "@/components/SeloTroca";
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { PedidoTroca } from "@/lib/escalas/consultas";
import { formatarDataHora } from "@/lib/escalas/datas";
import type { EstadoVaga } from "@/lib/escalas/estado";
import { cancelarPedidoTroca, decidirTroca, responderPedidoTroca } from "@/app/(app)/pedidos-de-troca/acoes";

function Escondidos({ p, extra }: { p: PedidoTroca; extra: Record<string, string> }) {
  return (
    <>
      <input type="hidden" name="pedido" value={p.id} />
      <input type="hidden" name="ministerio" value={p.ministerio_id} />
      <input type="hidden" name="escala" value={p.escala_id} />
      {Object.entries(extra).map(([k, v]) => <input key={k} type="hidden" name={k} value={v} />)}
    </>
  );
}

function AcoesIndicada({ p }: { p: PedidoTroca }) {
  const [estado, aceitar] = useActionState<EstadoForm, FormData>(responderPedidoTroca, {});
  return (
    <div className="flex flex-col gap-2">
      <MensagemErro texto={estado.erro} />
      <div className="grid grid-cols-2 gap-2">
        <form action={aceitar}>
          <Escondidos p={p} extra={{ aceita: "1" }} />
          <BotaoEnviar aria-label={`Aceitar o pedido de ${p.solicitante}`}>Aceitar</BotaoEnviar>
        </form>
        <form action={aceitar}>
          <Escondidos p={p} extra={{ aceita: "0" }} />
          <BotaoEnviar variante="secundario" aria-label={`Recusar o pedido de ${p.solicitante}`}>Recusar</BotaoEnviar>
        </form>
      </div>
    </div>
  );
}

function AcoesLider({ p }: { p: PedidoTroca }) {
  const [estado, acao] = useActionState<EstadoVaga, FormData>(decidirTroca, {});
  const [dispensado, setDispensado] = useState<EstadoVaga | null>(null);
  const avisos = estado.avisos && dispensado !== estado ? estado.avisos : [];

  // "Continuar mesmo assim" reenvia a aprovação com a ciência do líder.
  const continuar = (formData: FormData) => {
    formData.set("ciente", "1");
    acao(formData);
  };

  return (
    <div className="flex flex-col gap-2">
      <MensagemErro texto={estado.erro} />
      <form action={acao} className="flex flex-col gap-2">
        <Escondidos p={p} extra={{ aprova: "1" }} />
        <AvisosVaga avisos={avisos} aoDispensar={() => setDispensado(estado)} aoContinuar={continuar} />
        {avisos.length === 0 && <BotaoEnviar aria-label={`Aprovar a troca de ${p.solicitante} para ${p.indicada}`}>Aprovar</BotaoEnviar>}
      </form>
      <form action={acao}>
        <Escondidos p={p} extra={{ aprova: "0" }} />
        <BotaoEnviar variante="secundario" aria-label={`Recusar a troca de ${p.solicitante} para ${p.indicada}`}>Recusar</BotaoEnviar>
      </form>
    </div>
  );
}

function BotaoCancelar({ p }: { p: PedidoTroca }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(cancelarPedidoTroca, {});
  return (
    <form action={acao} className="flex flex-col gap-2">
      <MensagemErro texto={estado.erro} />
      <Escondidos p={p} extra={{}} />
      <BotaoEnviar variante="secundario" aria-label={`Cancelar o pedido de troca: ${p.evento}`}>Cancelar pedido</BotaoEnviar>
    </form>
  );
}

export function CartaoPedidoTroca({ pedido: p }: { pedido: PedidoTroca }) {
  return (
    <li className="flex flex-col gap-3 rounded-lg border border-slate-400 p-4">
      <Link href={`/ministerios/${p.ministerio_id}/escalas/${p.escala_id}`}
            className="flex flex-col gap-1 focus:outline-3 focus:outline-offset-2 focus:outline-blue-700">
        <p className="text-sm font-medium text-slate-700">{p.ministerio}</p>
        <p className="text-lg font-semibold">{p.evento}</p>
        <p className="text-base">{formatarDataHora(p.data, p.horario)}</p>
        <p className="text-base text-slate-800">Vaga: {p.funcao}{p.rotulo ? ` · ${p.rotulo}` : ""}</p>
      </Link>
      <p className="text-base">
        <span className="font-medium">{p.solicitante}</span> pede que <span className="font-medium">{p.indicada}</span> assuma a vaga.
      </p>
      <div><SeloTroca situacao={p.situacao} /></div>
      {p.pode_responder && <AcoesIndicada p={p} />}
      {p.pode_decidir && <AcoesLider p={p} />}
      {p.pode_cancelar && <BotaoCancelar p={p} />}
    </li>
  );
}
