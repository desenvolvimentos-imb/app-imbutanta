// Situação de uma pessoa numa data: ícone + texto + cor (nunca só a cor, WCAG).
import type { SituacaoNaData } from "@/lib/disponibilidade/consultas";

const ESTILO: Record<SituacaoNaData, { texto: string; icone: string; classes: string }> = {
  disponivel: { texto: "Disponível", icone: "✓", classes: "border-green-800 bg-green-50 text-green-950" },
  indisponivel: { texto: "Indisponível", icone: "✕", classes: "border-red-800 bg-red-50 text-red-950" },
  sem_resposta: { texto: "Sem resposta", icone: "?", classes: "border-amber-800 bg-amber-50 text-amber-950" },
};

export function SeloDisponibilidade({ situacao, preenchidaPeloLider = false }: { situacao: SituacaoNaData; preenchidaPeloLider?: boolean }) {
  const e = ESTILO[situacao];
  return (
    <span className={`inline-flex items-center gap-1 rounded border px-2 py-0.5 text-sm font-semibold ${e.classes}`}>
      <span aria-hidden="true">{e.icone}</span>
      {e.texto}
      {preenchidaPeloLider && <span className="font-normal"> (preenchido pelo líder)</span>}
    </span>
  );
}

/** Selo da situação da consulta: aberta ou fechada, com o motivo. */
export function SeloConsulta({ aberta, motivo }: { aberta: boolean; motivo: "lider" | "prazo" | "ministerio_desativado" | null }) {
  if (aberta) {
    return (
      <span className="inline-flex items-center gap-1 rounded border border-green-800 bg-green-50 px-2 py-0.5 text-sm font-semibold text-green-950">
        <span aria-hidden="true">●</span> Aberta
      </span>
    );
  }
  const texto = motivo === "prazo" ? "Prazo encerrado" : motivo === "ministerio_desativado" ? "Ministério desativado" : "Fechada";
  return (
    <span className="inline-flex items-center gap-1 rounded border border-slate-600 bg-slate-100 px-2 py-0.5 text-sm font-semibold text-slate-900">
      <span aria-hidden="true">■</span> {texto}
    </span>
  );
}
