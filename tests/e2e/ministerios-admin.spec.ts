// T025 (História 1): o administrador cria, edita e desativa ministérios; os demais não.
import { expect, test, type Page } from "@playwright/test";
import { entrarCom } from "./ajuda/login";

// Cria um ministério pela tela e devolve o resultado da tentativa (nome, líder inicial do seed).
async function criarMinisterio(page: Page, nome: string, descricao = "Descrição de teste") {
  await page.goto("/ministerios/novo");
  await page.getByLabel("Nome do ministério").fill(nome);
  await page.getByLabel("Descrição curta").fill(descricao);
  await page.getByLabel("Líder inicial").selectOption({ label: "Lucas Líder" });
  await page.getByRole("button", { name: "Criar ministério" }).click();
}

test("administrador cria um ministério com líder inicial e o vê na lista", async ({ page }) => {
  const nome = `Teatro ${Date.now()}`;
  await entrarCom(page, "admin@teste.local");
  await page.goto("/ministerios");
  await page.getByRole("link", { name: "Novo ministério" }).click();
  await expect(page).toHaveURL(/\/ministerios\/novo/);

  await page.getByLabel("Nome do ministério").fill(nome);
  await page.getByLabel("Descrição curta").fill("Peças e encenações");
  await page.getByLabel("Líder inicial").selectOption({ label: "Lucas Líder" });
  await page.getByRole("button", { name: "Criar ministério" }).click();

  // Depois de criar, abre o detalhe do ministério.
  await expect(page.getByRole("heading", { name: nome })).toBeVisible();
  await page.goto("/ministerios");
  await expect(page.getByRole("link", { name: new RegExp(nome) })).toBeVisible();
});

test("nome repetido (ignorando caixa e acento) é recusado com mensagem clara", async ({ page }) => {
  const nome = `Dança ${Date.now()}`;
  await entrarCom(page, "admin@teste.local");
  await criarMinisterio(page, nome);
  await expect(page.getByRole("heading", { name: nome })).toBeVisible();

  await criarMinisterio(page, nome.toUpperCase().replace("Ç", "C").replace("Ã", "A"));
  await expect(page.locator("p[role=alert]")).toContainText("Já existe um ministério ativo com esse nome.");
});

test("administrador desativa um ministério, que sai da lista de ativos, e pode reaproveitar o nome", async ({ page }) => {
  const nome = `Mídia ${Date.now()}`;
  await entrarCom(page, "admin@teste.local");
  await criarMinisterio(page, nome);
  await expect(page.getByRole("heading", { name: nome })).toBeVisible();

  // Desativar pede uma segunda confirmação (ação que afeta várias pessoas).
  await page.getByRole("button", { name: "Desativar ministério" }).click();
  await page.getByRole("button", { name: "Confirmar desativação" }).click();
  await expect(page.getByText("Ministério desativado")).toBeVisible();

  await page.goto("/ministerios");
  const ativos = page.getByRole("region", { name: "Ministérios ativos" });
  await expect(ativos.getByRole("link", { name: new RegExp(nome) })).toHaveCount(0);
  const desativados = page.getByRole("region", { name: "Ministérios desativados" });
  await expect(desativados.getByRole("link", { name: new RegExp(nome) })).toBeVisible();

  // O nome de um ministério desativado pode ser usado de novo.
  await criarMinisterio(page, nome);
  await expect(page.getByRole("heading", { name: nome })).toBeVisible();
});

test("membro e líder de ministério não criam nem acessam a tela de novo ministério", async ({ page }) => {
  await entrarCom(page, "membro@teste.local");
  await page.goto("/ministerios/novo");
  await expect(page).toHaveURL(/\/inicio/);
  await expect(page.getByRole("link", { name: "Novo ministério" })).toHaveCount(0);
  await page.context().clearCookies();

  await entrarCom(page, "lider@teste.local");
  await page.goto("/ministerios/novo");
  await expect(page).toHaveURL(/\/inicio/);
});
