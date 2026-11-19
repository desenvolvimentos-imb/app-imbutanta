// T066 (RF-020, CS-004): as regras valem mesmo SEM passar pela interface. Aqui falamos direto
// com a API do Supabase usando só a chave pública, como um atacante faria.
import { expect, test } from "@playwright/test";
import { clientePublico } from "./ajuda/admin";
import { SENHA } from "./ajuda/email";

async function logadoComo(email: string) {
  const cliente = clientePublico();
  const { error } = await cliente.auth.signInWithPassword({ email, password: SENHA });
  expect(error).toBeNull();
  return cliente;
}

test("sem login, nada de perfis nem de funções", async () => {
  const anonimo = clientePublico();
  const perfis = await anonimo.from("perfis").select("*");
  expect(perfis.error).not.toBeNull();
  expect(perfis.data).toBeNull();

  const decisao = await anonimo.rpc("decidir_cadastro", {
    p_perfil: "11111111-1111-1111-1111-111111111104",
    p_decisao: "aprovar",
    p_situacao_esperada: "pendente",
  });
  expect(decisao.error).not.toBeNull();

  const iniciais = await anonimo.from("administradores_iniciais").select("*");
  expect(iniciais.error).not.toBeNull();
});

test("membro só lê o próprio perfil e não decide, não promove e não apaga nada", async () => {
  const membro = await logadoComo("membro@teste.local");

  const { data } = await membro.from("perfis").select("email");
  expect(data).toEqual([{ email: "membro@teste.local" }]);

  const decisao = await membro.rpc("decidir_cadastro", {
    p_perfil: "11111111-1111-1111-1111-111111111104",
    p_decisao: "aprovar",
    p_situacao_esperada: "pendente",
  });
  expect(decisao.error?.message).toBe("sem_permissao");

  const promocao = await membro.rpc("alterar_papel", {
    p_perfil: "11111111-1111-1111-1111-111111111103",
    p_papel: "administrador",
    p_situacao_esperada: "aprovado",
  });
  expect(promocao.error?.message).toBe("sem_permissao");

  // Edição direta de campos protegidos é negada pelas permissões de coluna.
  const autopromocao = await membro.from("perfis").update({ papel: "administrador" }).eq("email", "membro@teste.local");
  expect(autopromocao.error).not.toBeNull();

  const exclusao = await membro.from("perfis").delete().eq("email", "lider@teste.local");
  expect(exclusao.error).not.toBeNull();
});

test("líder vê só a fila de pendentes, e nenhum outro perfil alheio", async () => {
  const lider = await logadoComo("lider@teste.local");
  const { data } = await lider.from("perfis").select("email, situacao");

  const alheios = (data ?? []).filter((p) => p.email !== "lider@teste.local");
  expect(alheios.every((p) => p.situacao === "pendente")).toBe(true);

  const gestao = await lider.rpc("alterar_situacao", {
    p_perfil: "11111111-1111-1111-1111-111111111103",
    p_nova: "acesso_removido",
    p_situacao_esperada: "aprovado",
  });
  expect(gestao.error?.message).toBe("sem_permissao");
});

test("recusado enxerga só o próprio perfil e não consegue se aprovar", async () => {
  const recusado = await logadoComo("recusado@teste.local");
  const { data } = await recusado.from("perfis").select("email");
  expect(data).toEqual([{ email: "recusado@teste.local" }]);

  const aprovar = await recusado.from("perfis").update({ situacao: "aprovado" }).eq("email", "recusado@teste.local");
  expect(aprovar.error).not.toBeNull();
});
