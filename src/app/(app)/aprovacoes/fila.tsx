"use client";
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import { decidirCadastro } from "./actions";

export type Pendente = { id: string; nome: string; criado_em: string };

// Data no formato brasileiro e fuso de São Paulo (constituição, restrições técnicas).
const formatarData = (iso: string) =>
  new Intl.DateTimeFormat("pt-BR", { dateStyle: "short", timeStyle: "short", timeZone: "America/Sao_Paulo" }).format(
    new Date(iso),
  );

function Decisao({ id, decisao, nome }: { id: string; decisao: "aprovar" | "recusar"; nome: string }) {
  return (
    <>
      <input type="hidden" name="id" value={id} />
      <input type="hidden" name="decisao" value={decisao} />
      <BotaoEnviar variante={decisao === "aprovar" ? "primario" : "secundario"} aria-label={`${decisao === "aprovar" ? "Aprovar" : "Recusar"} ${nome}`}>
        {decisao === "aprovar" ? "Aprovar" : "Recusar"}
      </BotaoEnviar>
    </>
  );
}

export function FilaDeAprovacao({ pendentes }: { pendentes: Pendente[] }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(decidirCadastro, {});

  if (pendentes.length === 0) {
    return (
      <>
        <MensagemErro texto={estado.erro} />
        <p className="rounded-lg bg-slate-100 p-4 text-lg">Ninguém aguardando aprovação no momento.</p>
      </>
    );
  }

  return (
    <>
      <MensagemErro texto={estado.erro} />
      <ul className="flex flex-col gap-4">
        {pendentes.map((p) => (
          <li key={p.id} className="flex flex-col gap-3 rounded-lg border border-slate-400 p-4">
            <div>
              <p className="text-lg font-semibold">{p.nome}</p>
              <p className="text-sm text-slate-700">Cadastro em {formatarData(p.criado_em)}</p>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <form action={acao}>
                <Decisao id={p.id} decisao="aprovar" nome={p.nome} />
              </form>
              <form action={acao}>
                <Decisao id={p.id} decisao="recusar" nome={p.nome} />
              </form>
            </div>
          </li>
        ))}
      </ul>
    </>
  );
}
