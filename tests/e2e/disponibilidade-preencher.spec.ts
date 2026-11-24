// T051 (História 4 da 004): o líder preenche a resposta de quem não respondeu (também com a consulta
// fechada), a grade marca "preenchido pelo líder", e a própria pessoa, ao alterar depois, remove a marca.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { entrarCom } from "./ajuda/login";
import { prepararMinisterio } from "./ajuda/disponibilidade";

test("líder preenche, grade marca, consulta fechada ainda aceita correção, pessoa altera e a marca some", async ({ page }) => {
  const c = await prepararMinisterio({ datas: [{ dias: 7 }, { dias: 14 }] });
  await page.setViewportSize({ width: 1280, height: 900 });

  await entrarCom(page, "lider@teste.local");
  await page.goto(`/ministerios/${c.ministerioId}/disponibilidade/${c.consultaId}`);
  const bloco = page.locator("details", { hasText: `Preencher ou corrigir: ${c.bia.nome}` });
  await bloco.locator("summary").click();
  await bloco.locator("fieldset").nth(0).getByRole("radio", { name: "Disponível", exact: true }).check();
  await bloco.locator("fieldset").nth(1).getByRole("radio", { name: "Indisponível", exact: true }).check();
  await bloco.getByRole("button", { name: /Salvar respostas de/ }).click();
  await expect(bloco.getByText("Respostas salvas.")).toBeVisible();
  await expect(page.getByRole("region", { name: "Grade de disponibilidade" }).getByText("(preenchido pelo líder)").first()).toBeVisible();

  // Consulta fechada: o líder ainda corrige.
  await clienteAdmin().from("consultas_disponibilidade").update({ fechada: true }).eq("id", c.consultaId);
  await page.reload();
  const bloco2 = page.locator("details", { hasText: `Preencher ou corrigir: ${c.bia.nome}` });
  await bloco2.locator("summary").click();
  await bloco2.locator("fieldset").nth(1).getByRole("radio", { name: "Disponível", exact: true }).check();
  await bloco2.getByRole("button", { name: /Salvar respostas de/ }).click();
  await expect(bloco2.getByText("Respostas salvas.")).toBeVisible();

  // A própria pessoa altera (consulta reaberta): a marca "preenchido pelo líder" some dessa resposta.
  await clienteAdmin().from("consultas_disponibilidade").update({ fechada: false }).eq("id", c.consultaId);
  await page.context().clearCookies();
  await entrarCom(page, c.bia.email);
  await page.goto(`/disponibilidade/${c.consultaId}`);
  await page.locator("fieldset").nth(0).getByRole("radio", { name: "Indisponível", exact: true }).check();
  await page.getByRole("button", { name: "Salvar respostas" }).click();
  await expect(page.getByText("Respostas salvas.")).toBeVisible();
  const { data } = await clienteAdmin().from("respostas_disponibilidade").select("data_id, preenchida_por").eq("perfil_id", c.bia.id);
  expect(data?.find((r) => r.data_id === c.dataIds[0])?.preenchida_por).toBeNull();
  expect(data?.find((r) => r.data_id === c.dataIds[1])?.preenchida_por).not.toBeNull();
});
