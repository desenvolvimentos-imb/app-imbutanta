// CS-009: verificação automática de acessibilidade (WCAG A/AA) das telas desta funcionalidade
// com axe-core. Cobre contraste, rótulos, nomes de botões, idioma etc. Não substitui a
// revisão manual (leitor de tela, zoom), que continua no checklist do PR.
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { entrarCom } from "./ajuda/login";

const TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"];

async function verificar(page: import("@playwright/test").Page, descricao: string) {
  const resultado = await new AxeBuilder({ page }).withTags(TAGS).analyze();
  const resumo = resultado.violations.map((v) => `${v.id}: ${v.help} (${v.nodes.length})`);
  expect(resumo, `Violações de acessibilidade em ${descricao}`).toEqual([]);

  // Mobile-first: nenhuma tela pode exigir rolagem horizontal no celular.
  const cabe = await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth);
  expect(cabe, `Rolagem horizontal em ${descricao}`).toBe(true);
}

test("telas públicas", async ({ page }) => {
  for (const rota of ["/entrar", "/cadastrar", "/recuperar-senha"]) {
    await page.goto(rota);
    await verificar(page, rota);
  }
});

test("telas de situação da conta", async ({ page }) => {
  await entrarCom(page, "pendente@teste.local");
  await verificar(page, "/aguardando-aprovacao");
  await page.context().clearCookies();

  await entrarCom(page, "recusado@teste.local");
  await verificar(page, "/cadastro-recusado");
});

test("telas do app por papel", async ({ page }) => {
  await entrarCom(page, "admin@teste.local");
  for (const rota of ["/inicio", "/aprovacoes", "/usuarios", "/conta"]) {
    await page.goto(rota);
    await verificar(page, rota);
  }
});

// Funcionalidade 002 (ministérios): telas novas e ajustadas, como administrador e como líder.
const LOUVOR = "22222222-2222-2222-2222-222222222201";
const TEATRO = "22222222-2222-2222-2222-222222222203"; // desativado: mostra reativar e confirmar

test("telas de ministérios (administrador)", async ({ page }) => {
  await entrarCom(page, "admin@teste.local");
  for (const rota of ["/ministerios", "/ministerios/novo", `/ministerios/${LOUVOR}`, `/ministerios/${TEATRO}`, "/meus-ministerios", "/aprovacoes"]) {
    await page.goto(rota);
    await verificar(page, rota);
  }
});

test("telas de ministérios (líder e membro)", async ({ page }) => {
  await entrarCom(page, "lider@teste.local");
  for (const rota of ["/ministerios", `/ministerios/${LOUVOR}`, "/meus-ministerios", "/aprovacoes"]) {
    await page.goto(rota);
    await verificar(page, rota);
  }
  await page.context().clearCookies();

  await entrarCom(page, "membro@teste.local");
  for (const rota of ["/ministerios", `/ministerios/${LOUVOR}`, "/meus-ministerios"]) {
    await page.goto(rota);
    await verificar(page, rota);
  }
});

test("desativar pede confirmação acessível", async ({ page }) => {
  await entrarCom(page, "admin@teste.local");
  await page.goto("/ministerios/22222222-2222-2222-2222-222222222202"); // Recepção (não desativa de fato)
  await page.getByRole("button", { name: "Desativar ministério" }).click();
  await expect(page.getByRole("button", { name: "Confirmar desativação" })).toBeVisible();
  await verificar(page, "confirmação de desativação");
});
