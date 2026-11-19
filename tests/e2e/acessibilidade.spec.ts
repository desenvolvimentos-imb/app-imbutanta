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
