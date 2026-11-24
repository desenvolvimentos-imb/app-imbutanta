// T008: atalho "todos os <dia da semana> do mês" e formatação das datas das consultas.
import { describe, expect, it } from "vitest";
import { datasDoDiaDaSemana, formatarDataConsulta, formatarDataCompleta, prazoVencido } from "@/lib/disponibilidade/datas";

describe("datasDoDiaDaSemana", () => {
  it("mês com 5 domingos (agosto de 2026)", () => {
    expect(datasDoDiaDaSemana(2026, 8, 0, "2026-01-01")).toEqual([
      "2026-08-02", "2026-08-09", "2026-08-16", "2026-08-23", "2026-08-30",
    ]);
  });
  it("mês com 4 domingos (dezembro de 2026)", () => {
    expect(datasDoDiaDaSemana(2026, 12, 0, "2026-11-24")).toEqual(["2026-12-06", "2026-12-13", "2026-12-20", "2026-12-27"]);
  });
  it("descarta as datas anteriores a hoje, mas mantém hoje", () => {
    expect(datasDoDiaDaSemana(2026, 12, 0, "2026-12-13")).toEqual(["2026-12-13", "2026-12-20", "2026-12-27"]);
    expect(datasDoDiaDaSemana(2026, 12, 0, "2026-12-28")).toEqual([]);
  });
  it("virada de ano (janeiro de 2027, quartas)", () => {
    expect(datasDoDiaDaSemana(2027, 1, 3, "2026-12-31")).toEqual(["2027-01-06", "2027-01-13", "2027-01-20", "2027-01-27"]);
  });
  it("fevereiro bissexto (2028) tem o dia 29", () => {
    expect(datasDoDiaDaSemana(2028, 2, 2, "2028-01-01")).toEqual(["2028-02-01", "2028-02-08", "2028-02-15", "2028-02-22", "2028-02-29"]);
  });
});

describe("formatação", () => {
  it("dia da semana por extenso, dia e mês", () => {
    expect(formatarDataConsulta("2026-12-06")).toBe("domingo, 06/12");
    expect(formatarDataConsulta("2026-12-09")).toBe("quarta-feira, 09/12");
  });
  it("data completa", () => {
    expect(formatarDataCompleta("2026-12-06")).toBe("06/12/2026");
  });
});

describe("prazoVencido", () => {
  it("vale até o fim do dia do prazo", () => {
    expect(prazoVencido("2026-12-10", "2026-12-10")).toBe(false);
    expect(prazoVencido("2026-12-10", "2026-12-11")).toBe(true);
    expect(prazoVencido(null, "2030-01-01")).toBe(false);
  });
});
