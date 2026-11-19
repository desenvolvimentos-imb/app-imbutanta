// T013: validação de nome, email e senha (RF-003, RF-006).
// Teste unitário = roda uma função pequena isolada e confere o resultado, sem internet.
import { describe, expect, it } from "vitest";
import { validarEmail, validarNome, validarSenha } from "@/lib/auth/validacao";

describe("validarNome", () => {
  it("aceita um nome normal e remove espaços das pontas", () => {
    expect(validarNome("  Maria Silva  ")).toEqual({ ok: true, valor: "Maria Silva" });
  });
  it("rejeita nome vazio", () => {
    expect(validarNome("").ok).toBe(false);
  });
  it("rejeita nome só com espaços", () => {
    expect(validarNome("     ").ok).toBe(false);
  });
  it("rejeita nome de 1 letra", () => {
    expect(validarNome("A").ok).toBe(false);
  });
  it("rejeita nome com mais de 100 caracteres", () => {
    expect(validarNome("a".repeat(101)).ok).toBe(false);
    expect(validarNome("a".repeat(100)).ok).toBe(true);
  });
  it("explica o problema em português", () => {
    const r = validarNome("");
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.mensagem).toMatch(/nome/i);
  });
});

describe("validarEmail", () => {
  it("aceita e normaliza para minúsculas", () => {
    expect(validarEmail(" Maria@Exemplo.COM ")).toEqual({ ok: true, valor: "maria@exemplo.com" });
  });
  it("rejeita vazio e formato inválido", () => {
    expect(validarEmail("").ok).toBe(false);
    expect(validarEmail("maria").ok).toBe(false);
    expect(validarEmail("maria@").ok).toBe(false);
  });
});

describe("validarSenha", () => {
  it("aceita senha com 8+ caracteres, letras e números", () => {
    expect(validarSenha("Senha1234").ok).toBe(true);
  });
  it("rejeita senha curta", () => {
    const r = validarSenha("abc123");
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.mensagem).toMatch(/8/);
  });
  it("rejeita senha sem número", () => {
    const r = validarSenha("somenteletras");
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.mensagem).toMatch(/números/i);
  });
  it("rejeita senha sem letra", () => {
    const r = validarSenha("123456789");
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.mensagem).toMatch(/letras/i);
  });
  it("não altera a senha (espaços fazem parte dela)", () => {
    expect(validarSenha("  Senha1234 ")).toEqual({ ok: true, valor: "  Senha1234 " });
  });
});
