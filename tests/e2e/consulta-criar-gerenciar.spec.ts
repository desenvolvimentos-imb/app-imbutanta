// T019 (História 1 da 004): o líder cria a consulta com o atalho "todos os <dia da semana> do mês",
// vê o erro de data repetida, edita, fecha e reabre; participante comum não vê as telas de gestão.
import { expect, test } from "@playwright/test";
import { entrarCom, sairDoApp } from "./ajuda/login";
import { diaEm, prepararMinisterio } from "./ajuda/disponibilidade";

test("líder cria, edita, fecha e reabre; participante comum não vê a gestão", async ({ page }) => {
  const c = await prepararMinisterio();
  const titulo = `Escala ${c.sufixo}`;

  await entrarCom(page, "lider@teste.local");
  await page.goto(`/ministerios/${c.ministerioId}/disponibilidade/nova`);
  await page.getByLabel("Título").fill(titulo);

  // Atalho: todos os dias da semana de um mês futuro (sempre há datas a partir de hoje).
  const futuro = diaEm(45).slice(0, 7);
  await page.getByLabel("Mês").fill(futuro);
  await page.getByLabel("Dia da semana").selectOption("0");
  await page.getByRole("button", { name: /Adicionar todos os dias \(domingo\)/ }).click();
  const itens = page.getByRole("listitem").filter({ hasText: "domingo," });
  await expect(itens.first()).toBeVisible();
  expect(await itens.count()).toBeGreaterThanOrEqual(4);
  const primeiro = await itens.first().locator("input[type=text]").inputValue();
  expect(primeiro).toBe("");
  await itens.first().locator("input[type=text]").fill("Culto especial");

  await page.getByRole("button", { name: "Criar consulta" }).click();
  await expect(page.getByRole("heading", { name: titulo, level: 1 })).toBeVisible();
  await expect(page.getByText("Aberta").first()).toBeVisible();
  const urlConsulta = page.url();

  // O atalho do ministério mostra quantas consultas estão abertas.
  await page.goto(`/ministerios/${c.ministerioId}`);
  await expect(page.getByText("1 consulta de disponibilidade aberta.")).toBeVisible();

  // ===== Data repetida em outra consulta do ministério: erro indicando a consulta =====
  await page.goto(`/ministerios/${c.ministerioId}/disponibilidade/nova`);
  await page.getByLabel("Título").fill("Outra consulta");
  await page.getByLabel("Mês").fill(futuro);
  await page.getByRole("button", { name: /Adicionar todos os dias \(domingo\)/ }).click();
  await page.getByRole("button", { name: "Criar consulta" }).click();
  await expect(page.getByText(`Essa data já está na consulta “${titulo}”`)).toBeVisible();

  // ===== Editar título e prazo =====
  await page.goto(urlConsulta);
  const editar = page.getByRole("region", { name: "Editar consulta" });
  await editar.getByLabel("Título").fill(`${titulo} (revisada)`);
  await editar.getByLabel("Prazo para responder (opcional)").fill(diaEm(3));
  await editar.getByRole("button", { name: "Salvar alterações" }).click();
  await expect(page.getByText("Alterações salvas.")).toBeVisible();

  // ===== Fechar e reabrir =====
  await page.getByRole("button", { name: "Fechar consulta" }).click();
  await expect(page.getByText("Fechada").first()).toBeVisible();
  await expect(page.getByRole("region", { name: "Editar consulta" })).toHaveCount(0);
  await page.getByRole("button", { name: "Reabrir consulta" }).click();
  await expect(page.getByText("Aberta").first()).toBeVisible();
  await expect(page.getByRole("region", { name: "Editar consulta" })).toBeVisible();

  // ===== Participante comum: sem telas de gestão =====
  await sairDoApp(page);
  await entrarCom(page, c.ana.email);
  expect((await page.goto(`/ministerios/${c.ministerioId}/disponibilidade`))?.status()).toBe(404);
  expect((await page.goto(urlConsulta))?.status()).toBe(404);
  expect((await page.goto(`/ministerios/${c.ministerioId}/disponibilidade/nova`))?.status()).toBe(404);
});
