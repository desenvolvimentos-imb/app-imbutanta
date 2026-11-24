// T034 (História 2 da 004): a tela inicial avisa da consulta; o participante responde parcialmente,
// altera, deixa observação; consulta fechada fica só leitura; quem não participa não acessa.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { entrarCom } from "./ajuda/login";
import { criarPessoa, prepararMinisterio } from "./ajuda/disponibilidade";

test("participante responde, altera e vê a consulta fechada em somente leitura", async ({ page }) => {
  const c = await prepararMinisterio({ datas: [{ dias: 7, rotulo: "Culto especial" }, { dias: 14 }, { dias: 21 }, { dias: 28 }] });
  const estranha = await criarPessoa("Estranha", c.sufixo);

  await entrarCom(page, c.ana.email);

  // A tela inicial avisa; a partir dela a consulta abre em 2 toques (constitution I: fluxo ≤ 3 toques).
  await page.goto("/inicio");
  await expect(page.getByText("Consulta aguardando sua resposta")).toBeVisible();
  await page.getByRole("link", { name: /^Disponibilidade/ }).click();
  await expect(page.getByText("4 datas sem resposta")).toBeVisible();
  await page.getByRole("link", { name: new RegExp(c.titulo) }).click();
  await expect(page.getByRole("heading", { name: c.titulo, level: 1 })).toBeVisible();
  await expect(page.getByText("Culto especial")).toBeVisible();

  const campos = page.locator("fieldset");
  // Salva parcial: 2 de 4 datas.
  await campos.nth(0).getByRole("radio", { name: "Disponível", exact: true }).check();
  await campos.nth(1).getByRole("radio", { name: "Indisponível", exact: true }).check();
  await page.getByRole("button", { name: "Salvar respostas" }).click();
  await expect(page.getByText("Respostas salvas. Faltam 2 datas.")).toBeVisible();

  // Altera uma resposta e deixa observação.
  await campos.nth(1).getByRole("radio", { name: "Disponível", exact: true }).check();
  await page.getByLabel("Observação para o líder (opcional)").fill("Prefiro a manhã");
  await expect(page.getByText("15 de 300 caracteres")).toBeVisible();
  await page.getByRole("button", { name: "Salvar respostas" }).click();
  await expect(page.getByText("Faltam 2 datas.")).toBeVisible();
  await page.reload();
  await expect(campos.nth(1).getByRole("radio", { name: "Disponível", exact: true })).toBeChecked();
  await expect(campos.nth(2).getByRole("radio", { name: "Sem resposta" })).toBeChecked();
  await expect(page.getByLabel("Observação para o líder (opcional)")).toHaveValue("Prefiro a manhã");

  // Responde tudo: o aviso da tela inicial some.
  await campos.nth(2).getByRole("radio", { name: "Indisponível", exact: true }).check();
  await campos.nth(3).getByRole("radio", { name: "Disponível", exact: true }).check();
  await page.getByRole("button", { name: "Salvar respostas" }).click();
  await expect(page.getByText("Tudo respondido.")).toBeVisible();
  await page.goto("/inicio");
  await expect(page.getByText("Consulta aguardando sua resposta")).toHaveCount(0);

  // Consulta fechada: só leitura.
  await clienteAdmin().from("consultas_disponibilidade").update({ fechada: true }).eq("id", c.consultaId);
  await page.goto(`/disponibilidade/${c.consultaId}`);
  await expect(page.getByText("Esta consulta está fechada.")).toBeVisible();
  await expect(page.getByRole("button", { name: "Salvar respostas" })).toHaveCount(0);
  await expect(campos.nth(0).getByRole("radio", { name: "Disponível", exact: true })).toBeDisabled();

  // Quem não participa do ministério não acessa a consulta por link direto.
  await page.context().clearCookies();
  await entrarCom(page, estranha.email);
  expect((await page.goto(`/disponibilidade/${c.consultaId}`))?.status()).toBe(404);
});
