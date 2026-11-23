// Situação de um pedido de troca: ícone + texto + cor (nunca só a cor).
import type { SituacaoTroca } from "@/lib/escalas/consultas";

const ESTILO: Record<SituacaoTroca, { texto: string; icone: string; classes: string }> = {
  aguardando_indicada: { texto: "Aguardando a pessoa indicada", icone: "…", classes: "border-amber-800 bg-amber-50 text-amber-950" },
  aguardando_lider: { texto: "Aguardando o líder", icone: "…", classes: "border-amber-800 bg-amber-50 text-amber-950" },
  aprovado: { texto: "Aprovado", icone: "✓", classes: "border-green-800 bg-green-50 text-green-950" },
  recusado_indicada: { texto: "Recusado pela pessoa indicada", icone: "✕", classes: "border-red-800 bg-red-50 text-red-950" },
  recusado_lider: { texto: "Recusado pelo líder", icone: "✕", classes: "border-red-800 bg-red-50 text-red-950" },
  cancelado: { texto: "Cancelado", icone: "–", classes: "border-slate-600 bg-slate-100 text-slate-900" },
  sem_efeito: { texto: "Sem efeito", icone: "–", classes: "border-slate-600 bg-slate-100 text-slate-900" },
};

export function SeloTroca({ situacao }: { situacao: SituacaoTroca }) {
  const e = ESTILO[situacao];
  return (
    <span className={`inline-flex items-center gap-1 rounded border px-2 py-0.5 text-sm font-semibold ${e.classes}`}>
      <span aria-hidden="true">{e.icone}</span>
      {e.texto}
    </span>
  );
}
