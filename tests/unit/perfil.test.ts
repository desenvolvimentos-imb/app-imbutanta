// Ler o perfil da pessoa logada: se o banco falhar ou o perfil não existir, o app NÃO pode
// fingir que está tudo bem (antes tratava como "pendente" e escondia o problema).
import { describe, expect, it, vi } from "vitest";
import { ErroPerfil, perfilOuFalha, type PerfilBanco } from "@/lib/auth/perfil";

const usuario = { id: "u1", email: "pessoa@exemplo.com" };

describe("perfilOuFalha", () => {
  it("devolve o perfil quando a consulta deu certo", () => {
    const linha: PerfilBanco = { id: "u1", nome: "Pessoa", email: "pessoa@exemplo.com", situacao: "aprovado", papel: "administrador" };
    expect(perfilOuFalha({ data: linha, error: null }, usuario)).toEqual(linha);
  });

  it("falha com ErroPerfil quando o banco devolve erro (ex.: tabela inexistente)", () => {
    const log = vi.spyOn(console, "error").mockImplementation(() => undefined);
    expect(() => perfilOuFalha({ data: null, error: { message: "relation does not exist" } }, usuario)).toThrow(ErroPerfil);
    expect(log).toHaveBeenCalled(); // o detalhe técnico vai para o log do servidor
    log.mockRestore();
  });

  it("falha com ErroPerfil quando a pessoa não tem perfil (conta criada sem o gatilho)", () => {
    const log = vi.spyOn(console, "error").mockImplementation(() => undefined);
    expect(() => perfilOuFalha({ data: null, error: null }, usuario)).toThrow(ErroPerfil);
    log.mockRestore();
  });

  it("a mensagem do erro não vaza texto técnico do banco", () => {
    const log = vi.spyOn(console, "error").mockImplementation(() => undefined);
    try {
      perfilOuFalha({ data: null, error: { message: "relation public.perfis does not exist" } }, usuario);
    } catch (e) {
      expect((e as Error).message).not.toMatch(/relation|perfis|does not exist/);
    }
    log.mockRestore();
  });
});
