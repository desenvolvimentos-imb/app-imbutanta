// T011: validação dos dados de escalas (mensagens em pt-BR).
import { describe, expect, it } from "vitest";
import {
  validarEscala, validarEvento, validarHorario, validarMotivo, validarNomeFuncao, validarObservacao,
  validarResposta, validarRotulo, validarTipoAptidao, validarId,
} from "@/lib/escalas/validacao";

describe("evento", () => {
  it("é obrigatório, de 2 a 80 caracteres, sem espaços nas pontas", () => {
    expect(validarEvento("  Culto de domingo ")).toEqual({ ok: true, valor: "Culto de domingo" });
    expect(validarEvento("")).toMatchObject({ ok: false, mensagem: "Informe o nome do evento." });
    expect(validarEvento("   ")).toMatchObject({ ok: false });
    expect(validarEvento("A")).toMatchObject({ ok: false });
    expect(validarEvento("x".repeat(81))).toMatchObject({ ok: false });
    expect(validarEvento(undefined)).toMatchObject({ ok: false });
  });
});

describe("horário", () => {
  it("aceita HH:MM e HH:MM:SS e normaliza para HH:MM", () => {
    expect(validarHorario("09:00")).toEqual({ ok: true, valor: "09:00" });
    expect(validarHorario("19:30:00")).toEqual({ ok: true, valor: "19:30" });
    expect(validarHorario("24:00")).toMatchObject({ ok: false });
    expect(validarHorario("9h")).toMatchObject({ ok: false });
    expect(validarHorario("")).toMatchObject({ ok: false });
  });
});

describe("campos opcionais", () => {
  it("observação, rótulo e motivo: ausente vira vazio e têm limite", () => {
    expect(validarObservacao(undefined)).toEqual({ ok: true, valor: "" });
    expect(validarObservacao("x".repeat(301))).toMatchObject({ ok: false });
    expect(validarRotulo(null)).toEqual({ ok: true, valor: "" });
    expect(validarRotulo("Vocal 1")).toEqual({ ok: true, valor: "Vocal 1" });
    expect(validarRotulo("x".repeat(41))).toMatchObject({ ok: false });
    expect(validarMotivo("x".repeat(201))).toMatchObject({ ok: false });
  });
});

describe("função e aptidão", () => {
  it("nome da função de 2 a 40; tipo principal ou secundária", () => {
    expect(validarNomeFuncao(" Violão ")).toEqual({ ok: true, valor: "Violão" });
    expect(validarNomeFuncao("V")).toMatchObject({ ok: false });
    expect(validarNomeFuncao("x".repeat(41))).toMatchObject({ ok: false });
    expect(validarTipoAptidao("principal")).toEqual({ ok: true, valor: "principal" });
    expect(validarTipoAptidao("terciaria")).toMatchObject({ ok: false });
  });
});

describe("resposta e id", () => {
  it("só confirmado ou recusado; id precisa ser UUID", () => {
    expect(validarResposta("confirmado")).toEqual({ ok: true, valor: "confirmado" });
    expect(validarResposta("pendente")).toMatchObject({ ok: false });
    expect(validarId("0b9f3b56-6a2e-4c33-9d3a-1c2f4b5a6d7e")).toMatchObject({ ok: true });
    expect(validarId("abc")).toMatchObject({ ok: false });
  });
});

describe("validarEscala", () => {
  it("valida tudo de uma vez e devolve a primeira mensagem", () => {
    expect(validarEscala({ evento: "Culto", data: "2026-12-14", horario: "09:00" })).toEqual({
      ok: true, valor: { evento: "Culto", data: "2026-12-14", horario: "09:00", observacao: "" },
    });
    expect(validarEscala({ evento: "", data: "2026-12-14", horario: "09:00" })).toMatchObject({ ok: false, mensagem: "Informe o nome do evento." });
    expect(validarEscala({ evento: "Culto", data: "2026-02-31", horario: "09:00" })).toMatchObject({ ok: false, mensagem: "Informe uma data válida." });
    expect(validarEscala({ evento: "Culto", data: "2026-12-14", horario: "" })).toMatchObject({ ok: false });
  });
});
