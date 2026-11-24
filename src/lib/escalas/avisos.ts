// Avisos ao líder ao escalar (ou ao aprovar uma troca). Eles NÃO bloqueiam: o líder pode continuar
// (FR-017, FR-018, FR-034). O servidor calcula os avisos; aqui ficam os tipos e os textos.

export type AvisoOutroMinisterio = {
  tipo: "outro_ministerio";
  ministerio: string;
  evento: string;
  /** "HH:MM" (ou "HH:MM:SS"). O horário só é informado, nunca comparado. */
  horario: string;
};

export type AvisoSemAptidao = { tipo: "sem_aptidao"; funcao: string };

export type Aviso = AvisoOutroMinisterio | AvisoSemAptidao;

/** Frase exigida pela especificação para o conflito entre ministérios. */
export const TEXTO_OUTRO_MINISTERIO = "participante já escalado em outro ministério neste mesmo dia";

/** Texto completo do aviso, em uma frase que o líder entende sem explicação. */
export function textoDoAviso(aviso: Aviso): string {
  if (aviso.tipo === "outro_ministerio") {
    return `${TEXTO_OUTRO_MINISTERIO}: ${aviso.ministerio}, ${aviso.evento}, às ${aviso.horario.slice(0, 5)}.`;
  }
  return `Esta pessoa não está apta para a função ${aviso.funcao}.`;
}

/** Aceita o que veio do banco (jsonb) e devolve só avisos bem formados. */
export function lerAvisos(bruto: unknown): Aviso[] {
  if (!Array.isArray(bruto)) return [];
  const avisos: Aviso[] = [];
  for (const item of bruto) {
    if (!item || typeof item !== "object") continue;
    const a = item as Record<string, unknown>;
    if (a.tipo === "outro_ministerio" && typeof a.ministerio === "string" && typeof a.evento === "string" && typeof a.horario === "string") {
      avisos.push({ tipo: "outro_ministerio", ministerio: a.ministerio, evento: a.evento, horario: a.horario });
    } else if (a.tipo === "sem_aptidao" && typeof a.funcao === "string") {
      avisos.push({ tipo: "sem_aptidao", funcao: a.funcao });
    }
  }
  return avisos;
}
