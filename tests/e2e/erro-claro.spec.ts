// Quando o app não consegue ler o perfil da pessoa logada (ou outro dado de uma página), ele mostra
// uma mensagem clara e NEUTRA em português, com saída (Sair), em vez de fingir que a conta está
// "pendente". A mensagem não cita "conta": a mesma tela serve para qualquer falha de carregamento.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, SENHA } from "./ajuda/email";
import { entrarCom } from "./ajuda/login";

test("conta sem perfil mostra erro claro e permite sair", async ({ page }) => {
  const admin = clienteAdmin();
  const email = emailNovo("semperfil");
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: SENHA,
    email_confirm: true,
    user_metadata: { nome: "Sem Perfil" },
  });
  if (error) throw error;
  // Simula o defeito: o usuário existe no Auth, mas a linha em `perfis` sumiu.
  await admin.from("perfis").delete().eq("id", data.user.id);

  await entrarCom(page, email);

  await expect(page.getByRole("heading", { name: "Não foi possível carregar esta página" })).toBeVisible();
  await expect(page.getByText(/aguardando aprovação/i)).toHaveCount(0); // não finge que está pendente
  await expect(page.getByRole("button", { name: "Tentar de novo" })).toBeVisible();

  await page.getByRole("button", { name: "Sair" }).click();
  await expect(page).toHaveURL(/\/entrar/);
});
