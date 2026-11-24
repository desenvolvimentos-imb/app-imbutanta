// T009: validação dos dados de consultas e respostas de disponibilidade.
import { describe, expect, it } from "vitest";
import {
  MAX_DATAS_POR_CONSULTA, validarConsulta, validarDatas, validarObservacao, validarRespostas,
} from "@/lib/disponibilidade/validacao";

const ID1 = "00000000-0000-4000-8000-000000000001";

describe("validarConsulta", () => {
  it("aceita título, mensagem e prazo opcionais", () => {
    const r = validarConsulta({ titulo: "  Escala de dezembro ", mensagem: "", prazo: "" });
    expect(r).toEqual({ ok: true, valor: { titulo: "Escala de dezembro", mensagem: "", prazo: null } });
    const r2 = validarConsulta({ titulo: "Ok", prazo: "2026-12-10" });
    expect(r2.ok && r2.valor.prazo).toBe("2026-12-10");
  });
  it("recusa título vazio, curto e longo", () => {
    expect(validarConsulta({ titulo: "" }).ok).toBe(false);
    expect(validarConsulta({ titulo: "A" }).ok).toBe(false);
    expect(validarConsulta({ titulo: "x".repeat(81) }).ok).toBe(false);
  });
  it("recusa mensagem acima de 500 e prazo inválido", () => {
    expect(validarConsulta({ titulo: "Ok", mensagem: "x".repeat(501) }).ok).toBe(false);
    expect(validarConsulta({ titulo: "Ok", prazo: "2026-02-31" }).ok).toBe(false);
  });
});

describe("validarDatas", () => {
  it("exige ao menos uma data e ordena", () => {
    expect(validarDatas([]).ok).toBe(false);
    const r = validarDatas([{ data: "2026-12-13", rotulo: "" }, { data: "2026-12-06", rotulo: " Culto especial " }]);
    expect(r.ok && r.valor).toEqual([
      { data: "2026-12-06", rotulo: "Culto especial" },
      { data: "2026-12-13", rotulo: "" },
    ]);
  });
  it("recusa data repetida, falsa, rótulo longo e mais de 31 datas", () => {
    expect(validarDatas([{ data: "2026-12-06" }, { data: "2026-12-06" }]).ok).toBe(false);
    expect(validarDatas([{ data: "2026-02-31" }]).ok).toBe(false);
    expect(validarDatas([{ data: "2026-12-06", rotulo: "x".repeat(41) }]).ok).toBe(false);
    const muitas = Array.from({ length: MAX_DATAS_POR_CONSULTA + 1 }, (_, i) => ({
      data: new Date(Date.UTC(2026, 0, i + 1)).toISOString().slice(0, 10),
    }));
    expect(validarDatas(muitas).ok).toBe(false);
  });
});

describe("observação e respostas", () => {
  it("observação de até 300 caracteres", () => {
    expect(validarObservacao("x".repeat(300)).ok).toBe(true);
    expect(validarObservacao("x".repeat(301)).ok).toBe(false);
    expect(validarObservacao(null)).toEqual({ ok: true, valor: "" });
  });
  it("respostas: disponível, indisponível ou nula (limpar)", () => {
    const r = validarRespostas([{ data_id: ID1, resposta: "disponivel" }, { data_id: ID1, resposta: null }]);
    expect(r.ok).toBe(true);
    expect(validarRespostas([{ data_id: ID1, resposta: "talvez" }]).ok).toBe(false);
    expect(validarRespostas([{ data_id: "x", resposta: "disponivel" }]).ok).toBe(false);
    expect(validarRespostas("nada").ok).toBe(false);
  });
});
