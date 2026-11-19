// T015: o parâmetro `voltar` só pode apontar para caminhos internos do app.
// Aceitar qualquer endereço permitiria "open redirect" (levar a pessoa a um site falso).
import { describe, expect, it } from "vitest";
import { caminhoVoltarSeguro } from "@/lib/auth/redirecionamento";

describe("caminhoVoltarSeguro", () => {
  it("aceita caminhos internos, com query", () => {
    expect(caminhoVoltarSeguro("/inicio")).toBe("/inicio");
    expect(caminhoVoltarSeguro("/aprovacoes?x=1")).toBe("/aprovacoes?x=1");
  });
  it("usa o padrão quando vazio ou ausente", () => {
    expect(caminhoVoltarSeguro(undefined)).toBe("/inicio");
    expect(caminhoVoltarSeguro(null)).toBe("/inicio");
    expect(caminhoVoltarSeguro("")).toBe("/inicio");
  });
  it("rejeita endereços externos", () => {
    expect(caminhoVoltarSeguro("https://malicioso.com")).toBe("/inicio");
    expect(caminhoVoltarSeguro("//malicioso.com")).toBe("/inicio");
    expect(caminhoVoltarSeguro("/\\malicioso.com")).toBe("/inicio");
    expect(caminhoVoltarSeguro("javascript:alert(1)")).toBe("/inicio");
  });
  it("rejeita quebras de linha e caracteres de controle", () => {
    expect(caminhoVoltarSeguro("/inicio\r\nSet-Cookie: x=1")).toBe("/inicio");
  });
  it("não volta para as rotas de autenticação (evita laço)", () => {
    expect(caminhoVoltarSeguro("/entrar")).toBe("/inicio");
    expect(caminhoVoltarSeguro("/auth/callback?code=1")).toBe("/inicio");
  });
  it("aceita padrão personalizado", () => {
    expect(caminhoVoltarSeguro("x", "/conta")).toBe("/conta");
  });
});
