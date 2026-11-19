// T016: tabela de redirecionamento por situação da conta e permissões por papel.
// A interface usa isto só por conveniência; quem garante a segurança é o banco (RLS).
import { describe, expect, it } from "vitest";
import { atalhosPorPapel, destinoPara, rotaDaSituacao } from "@/lib/auth/permissoes";

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
    expect(destinoPara("pendente", "membro", "/inicio")).toBe("/aguardando-aprovacao");
    expect(destinoPara("pendente", "membro", "/aprovacoes")).toBe("/aguardando-aprovacao");
    expect(destinoPara("pendente", "membro", "/aguardando-aprovacao")).toBeNull();
    expect(destinoPara("recusado", "membro", "/inicio")).toBe("/cadastro-recusado");
    expect(destinoPara("recusado", "membro", "/aguardando-aprovacao")).toBe("/cadastro-recusado");
    expect(destinoPara("acesso_removido", "membro", "/usuarios")).toBe("/acesso-removido");
  });
  it("aprovado não fica nas telas de situação", () => {
    expect(destinoPara("aprovado", "membro", "/aguardando-aprovacao")).toBe("/inicio");
    expect(destinoPara("aprovado", "membro", "/cadastro-recusado")).toBe("/inicio");
  });
  it("membro acessa início e conta, mas não aprovações nem usuários", () => {
    expect(destinoPara("aprovado", "membro", "/inicio")).toBeNull();
    expect(destinoPara("aprovado", "membro", "/conta")).toBeNull();
    expect(destinoPara("aprovado", "membro", "/aprovacoes")).toBe("/inicio");
    expect(destinoPara("aprovado", "membro", "/usuarios")).toBe("/inicio");
  });
  it("líder acessa aprovações, mas não usuários", () => {
    expect(destinoPara("aprovado", "lider", "/aprovacoes")).toBeNull();
    expect(destinoPara("aprovado", "lider", "/usuarios")).toBe("/inicio");
  });
  it("administrador acessa tudo", () => {
    expect(destinoPara("aprovado", "administrador", "/aprovacoes")).toBeNull();
    expect(destinoPara("aprovado", "administrador", "/usuarios")).toBeNull();
    expect(destinoPara("aprovado", "administrador", "/usuarios/outra")).toBeNull();
  });
  it("não confunde prefixos parecidos", () => {
    expect(destinoPara("aprovado", "membro", "/usuarios-falso")).toBeNull();
  });
});

describe("atalhosPorPapel", () => {
  it("membro não tem atalhos administrativos", () => {
    expect(atalhosPorPapel("membro")).toEqual([]);
  });
  it("líder vê Aprovar cadastros", () => {
    expect(atalhosPorPapel("lider").map((a) => a.href)).toEqual(["/aprovacoes"]);
  });
  it("administrador vê aprovações e usuários", () => {
    expect(atalhosPorPapel("administrador").map((a) => a.href)).toEqual(["/aprovacoes", "/usuarios"]);
  });
});
