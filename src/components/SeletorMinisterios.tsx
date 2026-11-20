// Caixas de marcar para escolher ministérios (cadastro e tela de espera). Marcar é só um
// PEDIDO: o líder do ministério decide. Não mostra nada se não houver ministério para escolher.
import type { Ministerio } from "@/lib/ministerios/consultas";

type Props = {
  ministerios: Pick<Ministerio, "id" | "nome" | "descricao">[];
  legenda: string;
  dica?: string;
};

export function SeletorMinisterios({ ministerios, legenda, dica }: Props) {
  if (ministerios.length === 0) return null;

  return (
    <fieldset className="flex flex-col gap-3 rounded-lg border border-slate-400 p-4">
      <legend className="px-1 text-base font-medium text-slate-900">{legenda}</legend>
      {dica && <p className="text-sm text-slate-700">{dica}</p>}
      {ministerios.map((m) => (
        <div key={m.id} className="flex items-start gap-3">
          <input
            id={`ministerio-${m.id}`}
            type="checkbox"
            name="ministerios"
            value={m.id}
            aria-describedby={m.descricao ? `ministerio-${m.id}-descricao` : undefined}
            className="mt-1 size-6 shrink-0 accent-blue-900"
          />
          <div className="flex flex-col">
            <label htmlFor={`ministerio-${m.id}`} className="min-h-6 text-base font-medium text-slate-900">
              {m.nome}
            </label>
            {m.descricao && (
              <span id={`ministerio-${m.id}-descricao`} className="text-sm text-slate-700">
                {m.descricao}
              </span>
            )}
          </div>
        </div>
      ))}
    </fieldset>
  );
}
