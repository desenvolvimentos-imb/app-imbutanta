// T012: avisos ao líder (não bloqueiam; FR-017, FR-018).
import { describe, expect, it } from "vitest";
import { lerAvisos, textoDoAviso, TEXTO_OUTRO_MINISTERIO } from "@/lib/escalas/avisos";

describe("textoDoAviso", () => {
  it("conflito com outro ministério usa a frase da especificação e mostra a outra escala", () => {
    const t = textoDoAviso({ tipo: "outro_ministerio", ministerio: "Recepção", evento: "Culto de domingo", horario: "09:00:00" });
    expect(t).toContain(TEXTO_OUTRO_MINISTERIO);
    expect(t).toContain("Recepção");
    expect(t).toContain("Culto de domingo");
    expect(t).toContain("09:00");
    expect(t).not.toContain("09:00:00");
  });
  it("falta de aptidão cita a função", () => {
    expect(textoDoAviso({ tipo: "sem_aptidao", funcao: "Violão" })).toBe("Esta pessoa não está apta para a função Violão.");
  });
});

describe("lerAvisos", () => {
  it("aceita avisos bem formados e ignora o resto", () => {
    const avisos = lerAvisos([
      { tipo: "outro_ministerio", ministerio: "A", evento: "B", horario: "09:00" },
      { tipo: "sem_aptidao", funcao: "Vocal" },
      { tipo: "desconhecido" },
      { tipo: "sem_aptidao" },
      null,
      "texto",
    ]);
    expect(avisos).toHaveLength(2);
  });
  it("entrada que não é lista vira lista vazia", () => {
    expect(lerAvisos(null)).toEqual([]);
    expect(lerAvisos({})).toEqual([]);
  });

  it("aviso de disponibilidade (004): lê e escreve em português", () => {
    const avisos = lerAvisos([
      { tipo: "sem_disponibilidade", resposta: "indisponivel" },
      { tipo: "sem_disponibilidade", resposta: "sem_resposta" },
      { tipo: "sem_disponibilidade", resposta: "disponivel" },
      { tipo: "sem_disponibilidade" },
    ]);
    expect(avisos).toHaveLength(2);
    expect(textoDoAviso(avisos[0])).toBe("Esta pessoa marcou que está indisponível nesta data.");
    expect(textoDoAviso(avisos[1])).toBe("Esta pessoa ainda não respondeu sobre esta data.");
  });
});
