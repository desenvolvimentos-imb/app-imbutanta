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
  it("códigos das funções de ministérios (002)", () => {
    expect(traduzirErro({ message: "nome_duplicado" })).toMatch(/Já existe um ministério ativo com esse nome/);
    expect(traduzirErro({ message: "nome_invalido" })).toMatch(/nome/i);
    expect(traduzirErro({ message: "ultimo_lider" })).toMatch(/pelo menos um líder/);
    expect(traduzirErro({ message: "ministerio_inativo" })).toMatch(/desativado/);
    expect(traduzirErro({ message: "ja_participa" })).toMatch(/já participa/);
    expect(traduzirErro({ message: "pedido_duplicado" })).toMatch(/pedido pendente/);
    expect(traduzirErro({ message: "conflito_pedido" })).toMatch(/já foi decidido/);
    expect(traduzirErro({ message: "pessoa_invalida" })).toMatch(/não pode ser adicionada/);
    expect(traduzirErro({ message: "sem_lider" })).toMatch(/Escolha um líder/);
  });
  it("ultimo_lider cita o ministério quando o banco informa o nome no detalhe", () => {
    const m = traduzirErro({ message: "ultimo_lider", details: "Louvor" } as never);
    expect(m).toMatch(/Louvor/);
    expect(m).toMatch(/pelo menos um líder/);
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

  it("escalas: cada código novo tem mensagem em português, sem texto técnico", () => {
    const codigos = [
      "funcao_duplicada", "funcao_invalida", "evento_invalido", "data_passada", "escala_somente_leitura",
      "escala_cancelada", "escala_sem_vagas", "escala_nao_publicada", "limite_vagas", "nao_participante",
      "evento_iniciado", "nao_escalado", "ja_escalada", "troca_duplicada", "conflito_troca", "troca_invalida", "motivo_invalido",
    ];
    for (const c of codigos) {
      const m = traduzirErro({ message: c });
      expect(m, c).not.toBe(c);
      expect(m, c).toMatch(/[.]$/);
      expect(m, c).not.toMatch(/Algo deu errado/);
    }
  });

  it("disponibilidade: cada código novo tem mensagem em português, sem texto técnico", () => {
    const codigos = [
      "consulta_invalida", "consulta_sem_datas", "consulta_fechada", "consulta_ja_aberta", "prazo_invalido",
      "prazo_vencido", "data_duplicada", "data_encerrada", "resposta_invalida",
    ];
    for (const c of codigos) {
      const m = traduzirErro({ message: c });
      expect(m, c).not.toBe(c);
      expect(m, c).toMatch(/[.]$/);
      expect(m, c).not.toMatch(/Algo deu errado/);
    }
  });
  it("data repetida cita o título da consulta que já tem a data", () => {
    expect(traduzirErro({ message: "data_duplicada", details: "Escala de dezembro" })).toContain("Escala de dezembro");
  });
});
