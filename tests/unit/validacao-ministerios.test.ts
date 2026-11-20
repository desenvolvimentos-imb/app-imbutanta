// T009: validação dos dados de ministério (RF-006) e dos ids marcados no cadastro (RF-015).
import { describe, expect, it } from "vitest";
import {
  LIMITE_MINISTERIOS_NO_CADASTRO,
  validarDescricaoMinisterio,
  validarIdsMinisterios,
  validarNomeMinisterio,
} from "@/lib/ministerios/validacao";

const UUID_A = "11111111-1111-4111-8111-111111111111";
const UUID_B = "22222222-2222-4222-8222-222222222222";

describe("validarNomeMinisterio", () => {
  it("aceita um nome normal e tira os espaços das pontas", () => {
    expect(validarNomeMinisterio("  Louvor  ")).toEqual({ ok: true, valor: "Louvor" });
  });
  it("rejeita nome vazio ou só com espaços", () => {
    expect(validarNomeMinisterio("")).toMatchObject({ ok: false, mensagem: expect.stringMatching(/Informe/) });
    expect(validarNomeMinisterio("     ")).toMatchObject({ ok: false });
  });
  it("rejeita nome curto demais (menos de 2 letras)", () => {
    expect(validarNomeMinisterio("A")).toMatchObject({ ok: false, mensagem: expect.stringMatching(/pelo menos 2/) });
  });
  it("aceita 60 caracteres e rejeita 61", () => {
    expect(validarNomeMinisterio("a".repeat(60))).toMatchObject({ ok: true });
    expect(validarNomeMinisterio("a".repeat(61))).toMatchObject({ ok: false, mensagem: expect.stringMatching(/60/) });
  });
  it("rejeita o que não é texto", () => {
    expect(validarNomeMinisterio(null)).toMatchObject({ ok: false });
    expect(validarNomeMinisterio(42)).toMatchObject({ ok: false });
  });
});

describe("validarDescricaoMinisterio", () => {
  it("descrição vazia é permitida", () => {
    expect(validarDescricaoMinisterio("")).toEqual({ ok: true, valor: "" });
    expect(validarDescricaoMinisterio(null)).toEqual({ ok: true, valor: "" });
  });
  it("aceita 200 caracteres e rejeita 201", () => {
    expect(validarDescricaoMinisterio("a".repeat(200))).toMatchObject({ ok: true });
    expect(validarDescricaoMinisterio("a".repeat(201))).toMatchObject({ ok: false, mensagem: expect.stringMatching(/200/) });
  });
  it("tira os espaços das pontas", () => {
    expect(validarDescricaoMinisterio("  Cantamos juntos  ")).toEqual({ ok: true, valor: "Cantamos juntos" });
  });
});

describe("validarIdsMinisterios", () => {
  it("mantém só UUIDs válidos", () => {
    expect(validarIdsMinisterios([UUID_A, UUID_B])).toEqual([UUID_A, UUID_B]);
  });
  it("ignora o que não é UUID, sem dar erro (o cadastro nunca falha por isso)", () => {
    expect(validarIdsMinisterios(["abc", "", UUID_A, "1; drop table x"])).toEqual([UUID_A]);
  });
  it("ignora valores que não são texto", () => {
    expect(validarIdsMinisterios([UUID_A, 7, null, undefined, {}])).toEqual([UUID_A]);
  });
  it("remove repetidos", () => {
    expect(validarIdsMinisterios([UUID_A, UUID_A.toUpperCase(), UUID_B])).toEqual([UUID_A, UUID_B]);
  });
  it("aceita um único valor (formulário com uma caixa marcada) e entradas vazias", () => {
    expect(validarIdsMinisterios(UUID_A)).toEqual([UUID_A]);
    expect(validarIdsMinisterios(undefined)).toEqual([]);
    expect(validarIdsMinisterios([])).toEqual([]);
  });
  it("limita a quantidade por cadastro", () => {
    const muitos = Array.from({ length: LIMITE_MINISTERIOS_NO_CADASTRO + 5 }, (_, i) =>
      `00000000-0000-4000-8000-${String(i).padStart(12, "0")}`,
    );
    expect(validarIdsMinisterios(muitos)).toHaveLength(LIMITE_MINISTERIOS_NO_CADASTRO);
  });
});
