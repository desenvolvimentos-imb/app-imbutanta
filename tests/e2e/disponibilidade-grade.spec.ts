// T044 (História 3 da 004): o líder acompanha a grade no celular (visão por data, sem rolagem
// horizontal da página) e no computador (tabela com coluna do nome fixa); contagem por função;
// destaque de quem não respondeu; observações. Participante comum não acessa; administrador vê tudo.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { entrarCom } from "./ajuda/login";
import { prepararMinisterio } from "./ajuda/disponibilidade";

async function prepararGrade() {
  const c = await prepararMinisterio({ datas: [{ dias: 7, rotulo: "Culto especial" }, { dias: 14 }, { dias: 21 }] });
  const admin = clienteAdmin();
  const { data: f } = await admin.from("funcoes_ministerio").insert({ ministerio_id: c.ministerioId, nome: "Vocal" }).select("id").single();
  await admin.from("aptidoes").insert({ funcao_id: f!.id, perfil_id: c.ana.id, tipo: "principal" });
  await admin.from("respostas_disponibilidade").insert([
    { data_id: c.dataIds[0], perfil_id: c.ana.id, resposta: "disponivel" },
    { data_id: c.dataIds[1], perfil_id: c.ana.id, resposta: "indisponivel" },
  ]);
  await admin.from("observacoes_disponibilidade").insert({ consulta_id: c.consultaId, perfil_id: c.ana.id, texto: "Só de manhã, por favor" });
  return c;
}

test("celular 360 px: visão por data legível, sem rolagem horizontal; e a tabela alternável", async ({ page }) => {
  const c = await prepararGrade();
  await page.setViewportSize({ width: 360, height: 740 });
  await entrarCom(page, "lider@teste.local");
  await page.goto(`/ministerios/${c.ministerioId}/disponibilidade/${c.consultaId}`);

  await expect(page.getByRole("heading", { name: c.titulo, level: 1 })).toBeVisible();
  // Quem não respondeu nada fica destacado.
  await expect(page.getByRole("status").filter({ hasText: "Ainda não responderam" })).toContainText(c.bia.nome);
  // Visão por data: totais, contagem por função e grupos.
  await expect(page.getByText("1 disponível").first()).toBeVisible();
  await expect(page.getByLabel("Disponíveis por função").first()).toContainText("Vocal: 1");
  await expect(page.getByLabel("Disponíveis por função").nth(1)).toContainText("Vocal: 0 (sem disponíveis)");
  await expect(page.getByText("Disponíveis (1)").first()).toBeVisible();
  await expect(page.getByText("Só de manhã, por favor").last()).toBeVisible();

  // A página não rola na horizontal.
  const larguras = await page.evaluate(() => ({ rolagem: document.documentElement.scrollWidth, janela: document.documentElement.clientWidth }));
  expect(larguras.rolagem).toBeLessThanOrEqual(larguras.janela);

  // Alterna para a tabela: só a tabela rola, e a coluna do nome é fixa.
  await page.getByRole("button", { name: "Tabela" }).click();
  const regiao = page.getByRole("region", { name: "Grade de disponibilidade" });
  await expect(regiao).toBeVisible();
  await expect(regiao.getByRole("rowheader", { name: new RegExp(c.ana.nome) })).toBeVisible();
  await expect(regiao.getByRole("row", { name: /Disponíveis/ })).toBeVisible();
  const fixa = await regiao.getByRole("rowheader", { name: new RegExp(c.ana.nome) }).evaluate((el) => getComputedStyle(el).position);
  expect(fixa).toBe("sticky");
  const larguras2 = await page.evaluate(() => ({ rolagem: document.documentElement.scrollWidth, janela: document.documentElement.clientWidth }));
  expect(larguras2.rolagem).toBeLessThanOrEqual(larguras2.janela);
});

test("computador: tabela por padrão; participante comum não acessa; administrador vê o ministério", async ({ page }) => {
  const c = await prepararGrade();
  await page.setViewportSize({ width: 1280, height: 900 });
  await entrarCom(page, "lider@teste.local");
  await page.goto(`/ministerios/${c.ministerioId}/disponibilidade/${c.consultaId}`);
  await expect(page.getByRole("region", { name: "Grade de disponibilidade" })).toBeVisible();

  await page.context().clearCookies();
  await entrarCom(page, c.ana.email);
  expect((await page.goto(`/ministerios/${c.ministerioId}/disponibilidade/${c.consultaId}`))?.status()).toBe(404);

  await page.context().clearCookies();
  await entrarCom(page, "admin@teste.local");
  await page.goto(`/ministerios/${c.ministerioId}/disponibilidade/${c.consultaId}`);
  await expect(page.getByRole("heading", { name: c.titulo, level: 1 })).toBeVisible();
});
