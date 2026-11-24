// T016/T007: tabela de redirecionamento por situação da conta e permissões por papel.
// Desde a funcionalidade 002 não existe papel global "líder": quem lidera um ministério ativo
// chega aqui como `lidera = true` (derivado das participações, lido do banco a cada requisição).
// A interface usa isto só por conveniência; quem garante a segurança é o banco (RLS).
import { describe, expect, it } from "vitest";
import { ATALHOS_MINISTERIOS, atalhosPorPapel, destinoPara, rotaDaSituacao } from "@/lib/auth/permissoes";

describe("rotaDaSituacao", () => {
  it("mapeia cada situação à sua tela", () => {
    expect(rotaDaSituacao("pendente")).toBe("/aguardando-aprovacao");
    expect(rotaDaSituacao("recusado")).toBe("/cadastro-recusado");
    expect(rotaDaSituacao("acesso_removido")).toBe("/acesso-removido");
    expect(rotaDaSituacao("aprovado")).toBe("/inicio");
  });
});

describe("destinoPara (null = pode ficar onde está)", () => {
  it("pendente, recusado e acesso removido só ficam na própria tela de situação", () => {
    expect(destinoPara("pendente", "membro", "/inicio", false)).toBe("/aguardando-aprovacao");
    expect(destinoPara("pendente", "membro", "/aprovacoes", false)).toBe("/aguardando-aprovacao");
    expect(destinoPara("pendente", "membro", "/aguardando-aprovacao", false)).toBeNull();
    expect(destinoPara("recusado", "membro", "/inicio", false)).toBe("/cadastro-recusado");
    expect(destinoPara("recusado", "membro", "/aguardando-aprovacao", false)).toBe("/cadastro-recusado");
    expect(destinoPara("acesso_removido", "membro", "/usuarios", false)).toBe("/acesso-removido");
  });
  it("aprovado não fica nas telas de situação", () => {
    expect(destinoPara("aprovado", "membro", "/aguardando-aprovacao", false)).toBe("/inicio");
    expect(destinoPara("aprovado", "membro", "/cadastro-recusado", false)).toBe("/inicio");
  });
  it("membro sem liderança acessa início, conta e ministérios, mas não aprovações nem usuários", () => {
    expect(destinoPara("aprovado", "membro", "/inicio", false)).toBeNull();
    expect(destinoPara("aprovado", "membro", "/conta", false)).toBeNull();
    expect(destinoPara("aprovado", "membro", "/meus-ministerios", false)).toBeNull();
    expect(destinoPara("aprovado", "membro", "/ministerios", false)).toBeNull();
    expect(destinoPara("aprovado", "membro", "/ministerios/abc", false)).toBeNull();
    expect(destinoPara("aprovado", "membro", "/aprovacoes", false)).toBe("/inicio");
    expect(destinoPara("aprovado", "membro", "/usuarios", false)).toBe("/inicio");
    expect(destinoPara("aprovado", "membro", "/ministerios/novo", false)).toBe("/inicio");
  });
  it("quem lidera algum ministério acessa aprovações, mas não usuários nem a criação de ministério", () => {
    expect(destinoPara("aprovado", "membro", "/aprovacoes", true)).toBeNull();
    expect(destinoPara("aprovado", "membro", "/usuarios", true)).toBe("/inicio");
    expect(destinoPara("aprovado", "membro", "/ministerios/novo", true)).toBe("/inicio");
  });
  it("administrador acessa tudo, com ou sem liderança", () => {
    expect(destinoPara("aprovado", "administrador", "/aprovacoes", false)).toBeNull();
    expect(destinoPara("aprovado", "administrador", "/usuarios", false)).toBeNull();
    expect(destinoPara("aprovado", "administrador", "/usuarios/outra", false)).toBeNull();
    expect(destinoPara("aprovado", "administrador", "/ministerios/novo", false)).toBeNull();
  });
  it("não confunde prefixos parecidos", () => {
    expect(destinoPara("aprovado", "membro", "/usuarios-falso", false)).toBeNull();
    expect(destinoPara("aprovado", "membro", "/ministerios/novo-falso", false)).toBeNull();
  });
});

describe("atalhosPorPapel (gestão)", () => {
  it("membro sem liderança não tem atalhos de gestão", () => {
    expect(atalhosPorPapel("membro", false)).toEqual([]);
  });
  it("quem lidera um ministério vê Pedidos e aprovações", () => {
    expect(atalhosPorPapel("membro", true).map((a) => a.href)).toEqual(["/aprovacoes"]);
  });
  it("administrador vê aprovações e usuários, lidere ou não", () => {
    expect(atalhosPorPapel("administrador", false).map((a) => a.href)).toEqual(["/aprovacoes", "/usuarios"]);
    expect(atalhosPorPapel("administrador", true).map((a) => a.href)).toEqual(["/aprovacoes", "/usuarios"]);
  });
});

describe("ATALHOS_MINISTERIOS (para todos)", () => {
  it("todos têm Meus ministérios e Ministérios", () => {
    expect(ATALHOS_MINISTERIOS.map((a) => a.href)).toEqual(["/meus-ministerios", "/ministerios"]);
  });
});

describe("rotas de escalas (003): sem regra de rota nova; a barreira por ministério é do banco", () => {
  const rotas = [
    "/minhas-escalas",
    "/pedidos-de-troca",
    "/ministerios/0b9f3b56-6a2e-4c33-9d3a-1c2f4b5a6d7e/escalas",
    "/ministerios/0b9f3b56-6a2e-4c33-9d3a-1c2f4b5a6d7e/escalas/nova",
    "/ministerios/0b9f3b56-6a2e-4c33-9d3a-1c2f4b5a6d7e/funcoes",
  ];
  it("qualquer pessoa aprovada chega às telas (o banco decide o que ela vê)", () => {
    for (const r of rotas) {
      expect(destinoPara("aprovado", "membro", r, false), r).toBeNull();
      expect(destinoPara("aprovado", "membro", r, true), r).toBeNull();
      expect(destinoPara("aprovado", "administrador", r, false), r).toBeNull();
    }
  });
  it("quem não está aprovado continua preso à tela da sua situação", () => {
    expect(destinoPara("pendente", "membro", "/minhas-escalas", false)).toBe("/aguardando-aprovacao");
    expect(destinoPara("recusado", "membro", "/pedidos-de-troca", false)).toBe("/cadastro-recusado");
  });
});
