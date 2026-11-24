// T010: datas das escalas sempre no fuso de São Paulo (FR-007, FR-027, FR-037).
import { describe, expect, it } from "vitest";
import { dataValida, formatarData, formatarDataHora, formatarHorario, hoje, jaComecou, somenteLeitura } from "@/lib/escalas/datas";

// São Paulo é UTC-3 o ano todo (sem horário de verão desde 2019).
const meiaNoiteMenos30EmSp = new Date("2026-12-10T02:30:00Z"); // 23:30 de 9/12 em SP
const meiaNoiteMais30EmSp = new Date("2026-12-10T03:30:00Z"); // 00:30 de 10/12 em SP

describe("hoje", () => {
  it("usa o dia de São Paulo mesmo quando em UTC já é o dia seguinte", () => {
    expect(hoje(meiaNoiteMenos30EmSp)).toBe("2026-12-09");
    expect(hoje(meiaNoiteMais30EmSp)).toBe("2026-12-10");
  });
});

describe("jaComecou", () => {
  const agora = new Date("2026-12-14T12:00:00Z"); // 09:00 de 14/12 em SP
  it("data passada já começou; data futura não", () => {
    expect(jaComecou("2026-12-13", "20:00", agora)).toBe(true);
    expect(jaComecou("2026-12-15", "00:00", agora)).toBe(false);
  });
  it("no mesmo dia, compara o horário (começa exatamente no minuto do início)", () => {
    expect(jaComecou("2026-12-14", "08:59", agora)).toBe(true);
    expect(jaComecou("2026-12-14", "09:00", agora)).toBe(true);
    expect(jaComecou("2026-12-14", "09:01", agora)).toBe(false);
    expect(jaComecou("2026-12-14", "09:00:00", agora)).toBe(true);
  });
});

describe("somenteLeitura", () => {
  it("só a partir do dia seguinte à data", () => {
    expect(somenteLeitura("2026-12-10", meiaNoiteMais30EmSp)).toBe(false); // é o próprio dia
    expect(somenteLeitura("2026-12-09", meiaNoiteMais30EmSp)).toBe(true); // ontem
    expect(somenteLeitura("2026-12-09", meiaNoiteMenos30EmSp)).toBe(false); // ainda é dia 9 em SP
  });
});

describe("dataValida", () => {
  it("aceita datas reais e rejeita as impossíveis", () => {
    expect(dataValida("2026-12-14")).toBe(true);
    expect(dataValida("2028-02-29")).toBe(true);
    expect(dataValida("2026-02-29")).toBe(false);
    expect(dataValida("2026-13-01")).toBe(false);
    expect(dataValida("14/12/2026")).toBe(false);
    expect(dataValida("")).toBe(false);
  });
});

describe("formatação pt-BR", () => {
  it("dia da semana, dia/mês e horário", () => {
    expect(formatarData("2026-12-14")).toMatch(/^seg\.?,? 14\/12$/);
    expect(formatarHorario("09:00:00")).toBe("09:00");
    expect(formatarDataHora("2026-12-14", "09:00:00")).toMatch(/^seg\.?,? 14\/12 às 09:00$/);
  });
  it("não quebra com texto inesperado", () => {
    expect(formatarData("qualquer")).toBe("qualquer");
  });
});
