// Selo de destaque de uma vaga para o líder: recusada, sem resposta ou em aberto (FR-023, FR-028).
// Usa ícone + texto + cor (nunca só a cor), por acessibilidade.
type Tipo = "recusada" | "sem_resposta" | "em_aberto";

const ESTILO: Record<Tipo, { texto: string; icone: string; classes: string }> = {
  recusada: { texto: "Recusou", icone: "✕", classes: "border-red-800 bg-red-50 text-red-950" },
  sem_resposta: { texto: "Sem resposta", icone: "?", classes: "border-amber-800 bg-amber-50 text-amber-950" },
  em_aberto: { texto: "Em aberto", icone: "!", classes: "border-orange-800 bg-orange-50 text-orange-950" },
};

export function DestaqueVaga({ tipo }: { tipo: Tipo | null | undefined }) {
  if (!tipo) return null;
  const e = ESTILO[tipo];
  return (
    <span className={`inline-flex items-center gap-1 rounded border px-2 py-0.5 text-sm font-semibold ${e.classes}`}>
      <span aria-hidden="true">{e.icone}</span>
      {e.texto}
    </span>
  );
}
