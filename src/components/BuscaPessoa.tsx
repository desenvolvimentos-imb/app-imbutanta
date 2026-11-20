"use client";
// Busca de pessoas por nome para adicionar a um ministério. A busca é um formulário comum (GET):
// a página recarrega com `?busca=` e o servidor devolve só nome (nunca email).
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { PessoaAprovada } from "@/lib/ministerios/consultas";
import { adicionarParticipante } from "@/app/(app)/ministerios/[id]/actions";

type Props = { ministerioId: string; termo: string; resultados: PessoaAprovada[] };

export function BuscaPessoa({ ministerioId, termo, resultados }: Props) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(adicionarParticipante, {});
  const buscou = termo.trim().length > 0;

  return (
    <div className="flex flex-col gap-4">
      <form method="get" className="flex flex-col gap-2">
        <label htmlFor="busca" className="text-base font-medium text-slate-900">
          Buscar pessoa por nome
        </label>
        <input
          id="busca"
          name="busca"
          type="search"
          defaultValue={termo}
          minLength={2}
          autoComplete="off"
          className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base text-slate-900 focus:outline-3 focus:outline-offset-2 focus:outline-blue-700"
        />
        <button
          type="submit"
          className="inline-flex min-h-12 w-full items-center justify-center rounded-lg border border-slate-500 bg-white px-4 text-base font-semibold text-slate-900 hover:bg-slate-100 focus:outline-3 focus:outline-offset-2 focus:outline-blue-700"
        >
          Buscar
        </button>
      </form>

      <MensagemErro texto={estado.erro} />

      {buscou && termo.trim().length < 2 && <p className="text-base text-slate-800">Digite pelo menos 2 letras.</p>}
      {buscou && termo.trim().length >= 2 && resultados.length === 0 && (
        <p className="rounded-lg bg-slate-100 p-3 text-base">
          Ninguém encontrado. Só aparecem pessoas com conta aprovada que ainda não participam deste ministério.
        </p>
      )}
      {resultados.length > 0 && (
        <ul className="flex flex-col gap-3">
          {resultados.map((p) => (
            <li key={p.id} className="flex flex-col gap-2 rounded-lg border border-slate-400 p-3">
              <p className="text-lg font-semibold">{p.nome}</p>
              <form action={acao}>
                <input type="hidden" name="id" value={ministerioId} />
                <input type="hidden" name="pessoa" value={p.id} />
                <BotaoEnviar aria-label={`Adicionar ${p.nome}`}>Adicionar</BotaoEnviar>
              </form>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
