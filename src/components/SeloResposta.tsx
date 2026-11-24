// Situação da resposta de quem está escalado: ícone + texto + cor (nunca só a cor).
import type { RespostaEscala } from "@/lib/escalas/consultas";

const ESTILO: Record<RespostaEscala, { texto: string; icone: string; classes: string }> = {
  pendente: { texto: "Pendente", icone: "?", classes: "border-amber-800 bg-amber-50 text-amber-950" },
  confirmado: { texto: "Confirmado", icone: "✓", classes: "border-green-800 bg-green-50 text-green-950" },
  recusado: { texto: "Recusado", icone: "✕", classes: "border-red-800 bg-red-50 text-red-950" },
};

export function SeloResposta({ resposta }: { resposta: RespostaEscala }) {
  const e = ESTILO[resposta];
  return (
    <span className={`inline-flex items-center gap-1 rounded border px-2 py-0.5 text-sm font-semibold ${e.classes}`}>
      <span aria-hidden="true">{e.icone}</span>
      {e.texto}
    </span>
  );
}
