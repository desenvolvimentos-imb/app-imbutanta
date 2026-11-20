// T059 (História 6): cada papel vê só o que lhe cabe nas telas de ministério (RF-029 a RF-032).
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { emailNovo, SENHA } from "./ajuda/email";
import { entrarCom } from "./ajuda/login";

const LOUVOR = "22222222-2222-2222-2222-222222222201"; // Lucas lidera, Marta participa
const RECEPCAO = "22222222-2222-2222-2222-222222222202"; // administradora lidera
const TEATRO = "22222222-2222-2222-2222-222222222203"; // desativado

test("administrador vê ministérios ativos e desativados, com participantes", async ({ page }) => {
  await entrarCom(page, "admin@teste.local");
  await page.goto("/ministerios");
  await expect(page.getByRole("region", { name: "Ministérios ativos" }).getByRole("link", { name: /Louvor/ })).toBeVisible();
  await expect(page.getByRole("region", { name: "Ministérios desativados" }).getByRole("link", { name: /Teatro/ })).toBeVisible();

  await page.goto(`/ministerios/${LOUVOR}`);
  const participantes = page.getByRole("region", { name: /Participantes/ });
  await expect(participantes.getByText("Lucas Líder")).toBeVisible();
  await expect(participantes.getByText("Marta Membro")).toBeVisible();

  await page.goto(`/ministerios/${TEATRO}`);
  await expect(page.getByText("Ministério desativado")).toBeVisible();
});

test("líder gere o próprio ministério; no outro vê só nome e descrição", async ({ page }) => {
  await entrarCom(page, "lider@teste.local");

  await page.goto(`/ministerios/${LOUVOR}`);
  await expect(page.getByLabel("Buscar pessoa por nome")).toBeVisible();
  await expect(page.getByRole("region", { name: /Participantes/ }).getByText("Marta Membro")).toBeVisible();
  await expect(page.getByRole("button", { name: "Desativar ministério" })).toHaveCount(0); // só o administrador desativa

  await page.goto(`/ministerios/${RECEPCAO}`);
  await expect(page.getByRole("heading", { name: "Recepção" })).toBeVisible();
  await expect(page.getByRole("region", { name: /Participantes/ })).toHaveCount(0);
  await expect(page.getByLabel("Buscar pessoa por nome")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Pedir para entrar em Recepção" })).toBeVisible();
});

test("participante vê quem faz parte do próprio ministério, sem ações de gestão, e nada do outro", async ({ page }) => {
  await entrarCom(page, "membro@teste.local"); // Marta
  await page.goto(`/ministerios/${LOUVOR}`);
  await expect(page.getByRole("region", { name: /Participantes/ }).getByText("Lucas Líder")).toBeVisible();
  await expect(page.getByLabel("Buscar pessoa por nome")).toHaveCount(0);
  await expect(page.getByRole("button", { name: /Promover|Rebaixar|Remover/ })).toHaveCount(0);

  await page.goto(`/ministerios/${RECEPCAO}`);
  await expect(page.getByRole("region", { name: /Participantes/ })).toHaveCount(0);
});

test("membro sem vínculo vê só nome e descrição e pode pedir; ministério desativado não existe para ele", async ({ page }) => {
  const email = emailNovo("visib");
  const admin = clienteAdmin();
  const { data, error } = await admin.auth.admin.createUser({ email, password: SENHA, email_confirm: true, user_metadata: { nome: "Sem Vinculo" } });
  if (error) throw error;
  await admin.from("perfis").update({ situacao: "aprovado" }).eq("id", data.user.id);

  await entrarCom(page, email);
  await page.goto("/ministerios");
  await expect(page.getByRole("link", { name: /Louvor/ })).toBeVisible();
  await expect(page.getByRole("link", { name: "Novo ministério" })).toHaveCount(0);
  await expect(page.getByRole("region", { name: "Ministérios desativados" })).toHaveCount(0);

  await page.goto(`/ministerios/${LOUVOR}`);
  await expect(page.getByRole("heading", { name: "Louvor" })).toBeVisible();
  await expect(page.getByRole("region", { name: /Participantes/ })).toHaveCount(0);
  await expect(page.getByText("Marta Membro")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Pedir para entrar em Louvor" })).toBeVisible();

  const resposta = await page.goto(`/ministerios/${TEATRO}`);
  expect(resposta?.status()).toBe(404);
});
