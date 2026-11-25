// Quantos disponíveis há por função em uma data; função sem ninguém fica em destaque (RF-025),
// com ícone + texto, nunca só a cor.
import type { PorFuncao } from "@/lib/disponibilidade/consultas";

export function ContagemPorFuncao({ itens }: { itens: PorFuncao[] }) {
  if (itens.length === 0) return null;
  return (
    <ul className="flex flex-wrap gap-2" aria-label="Disponíveis por função">
      {itens.map((f) => (
        <li key={f.funcao_id}
            className={`rounded border px-2 py-1 text-sm ${f.faltando ? "border-red-800 bg-red-50 font-semibold text-red-950" : "border-slate-400 bg-white text-slate-900"}`}>
          {f.faltando && <span aria-hidden="true">⚠ </span>}
          {f.funcao}: {f.disponiveis}
          {f.faltando && <span> (sem disponíveis)</span>}
        </li>
      ))}
    </ul>
  );
}
