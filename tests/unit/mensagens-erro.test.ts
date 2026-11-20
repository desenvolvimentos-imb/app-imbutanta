// T014: tradução de erros do Supabase e das funções SQL para mensagens em pt-BR
// (RF-007, RF-034): nunca mostrar erro técnico cru e nunca revelar se um email existe.
import { describe, expect, it, vi } from "vitest";
import { traduzirErro } from "@/lib/auth/mensagens-erro";

describe("traduzirErro", () => {
  it("credenciais inválidas: mensagem genérica, sem dizer qual campo errou", () => {
    const m = traduzirErro({ code: "invalid_credentials", message: "Invalid login credentials" });
    expect(m).toBe("Email ou senha incorretos.");
  });
  it("limite de tentativas (código ou status 429)", () => {
    expect(traduzirErro({ code: "over_request_rate_limit" })).toMatch(/Muitas tentativas/);
    expect(traduzirErro({ status: 429 })).toMatch(/Muitas tentativas/);
  });
  it("email já cadastrado não revela que a conta existe", () => {
    const m = traduzirErro({ code: "user_already_exists" });
    expect(m).not.toMatch(/já (existe|está cadastrado)/i);
    expect(m).toMatch(/Não foi possível criar a conta/);
    expect(traduzirErro({ code: "email_exists" })).toBe(m);
  });
  it("senha fraca", () => {
    expect(traduzirErro({ code: "weak_password" })).toMatch(/senha/i);
  });
  it("link expirado", () => {
    expect(traduzirErro({ code: "otp_expired" })).toMatch(/expirou/);
  });
  it("email ainda não confirmado", () => {
    expect(traduzirErro({ code: "email_not_confirmed" })).toMatch(/confirme/i);
  });
  it("códigos das funções do banco (message = código)", () => {
    expect(traduzirErro({ message: "sem_permissao" })).toMatch(/permissão/);
    expect(traduzirErro({ message: "conflito_situacao" })).toMatch(/mudou/);
    expect(traduzirErro({ message: "transicao_invalida" })).toMatch(/não é permitida/);
    expect(traduzirErro({ message: "ultimo_administrador" })).toMatch(/sem administrador|único administrador/);
    expect(traduzirErro({ message: "nao_encontrado" })).toMatch(/não encontrada/);
  });
  it("falha de rede", () => {
    expect(traduzirErro({ message: "Failed to fetch" })).toMatch(/conexão/i);
    expect(traduzirErro(new TypeError("fetch failed"))).toMatch(/conexão/i);
  });
  it("erro desconhecido ou vazio cai em mensagem genérica, sem texto técnico", () => {
    const m = traduzirErro({ message: "duplicate key value violates unique constraint xyz" });
    expect(m).not.toMatch(/duplicate|constraint/);
    expect(traduzirErro(null)).toBe(m);
    expect(traduzirErro(undefined)).toBe(m);
  });

  it("erro sem tradução vai para o log do servidor com o motivo real, sem aparecer na tela", () => {
    const log = vi.spyOn(console, "error").mockImplementation(() => {});
    const m = traduzirErro({
      code: "unexpected_failure",
      status: 500,
      message: '535 "5.7.8 Username and Password not accepted"',
    });
    expect(m).not.toMatch(/535|Username/);
    expect(log).toHaveBeenCalledTimes(1);
    const registrado = JSON.stringify(log.mock.calls[0]);
    expect(registrado).toContain("unexpected_failure");
    expect(registrado).toContain("535");
    log.mockRestore();
  });
  it("erro já traduzido não polui o log", () => {
    const log = vi.spyOn(console, "error").mockImplementation(() => {});
    traduzirErro({ code: "invalid_credentials" });
    traduzirErro({ status: 429 });
    expect(log).not.toHaveBeenCalled();
    log.mockRestore();
  });
  it("o log não grava emails de pessoas (dados mínimos, LGPD)", () => {
    const log = vi.spyOn(console, "error").mockImplementation(() => {});
    traduzirErro({ code: "email_address_invalid", message: 'Email address "maria@exemplo.com" is invalid' });
    const registrado = JSON.stringify(log.mock.calls[0]);
    expect(registrado).not.toContain("maria@exemplo.com");
    expect(registrado).toContain("email_address_invalid");
    log.mockRestore();
  });
});
