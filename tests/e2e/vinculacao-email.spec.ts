// T040 (História 2, RF-005): o mesmo email é sempre uma única conta.
// LIMITE: o login com Google real não é automatizável. Aqui provamos a metade que dá:
// repetir o cadastro com o mesmo email não cria perfil duplicado. A vinculação Google +
// senha é verificada no roteiro manual (quickstart.md, seção 4).
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, esperarEmail, extrairLink, SENHA } from "./ajuda/email";

test("cadastrar duas vezes com o mesmo email não duplica a conta", async ({ page }) => {
  const email = emailNovo("unico");

  for (let i = 0; i < 2; i++) {
    // O Supabase só aceita reenviar o email de confirmação após alguns segundos.
    if (i > 0) await page.waitForTimeout(2000);
    await page.goto("/cadastrar");
    await page.getByLabel("Nome").fill("Pessoa Única");
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Senha").fill(SENHA);
    await page.getByRole("button", { name: "Criar conta" }).click();
    await expect(page.getByText(/enviamos um link/i)).toBeVisible();
  }

  await page.goto(extrairLink(await esperarEmail(email, 2), "/auth/confirmar"));
  await expect(page).toHaveURL(/\/aguardando-aprovacao/);

  const { data } = await clienteAdmin().from("perfis").select("id").eq("email", email);
  expect(data).toHaveLength(1);
});
