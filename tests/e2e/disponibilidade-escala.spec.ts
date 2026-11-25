// T058 (História 5 da 004): ao escalar, o líder vê a resposta da pessoa na data da escala, recebe o
// aviso (sem bloqueio) e a indicação fica ao lado da pessoa; sem consulta na data, nada aparece.
import { expect, test } from "@playwright/test";
import { clienteAdmin } from "./ajuda/admin";
import { entrarCom } from "./ajuda/login";
import { diaEm, prepararMinisterio } from "./ajuda/disponibilidade";

test("aviso de disponibilidade ao escalar e indicação ao lado da pessoa", async ({ page }) => {
  const c = await prepararMinisterio({ datas: [{ dias: 10 }] });
  const admin = clienteAdmin();
  const { data: f } = await admin.from("funcoes_ministerio").insert({ ministerio_id: c.ministerioId, nome: "Vocal" }).select("id").single();
  await admin.from("aptidoes").insert([
    { funcao_id: f!.id, perfil_id: c.ana.id, tipo: "principal" },
    { funcao_id: f!.id, perfil_id: c.bia.id, tipo: "principal" },
  ]);
  await admin.from("respostas_disponibilidade").insert([
    { data_id: c.dataIds[0], perfil_id: c.ana.id, resposta: "disponivel" },
    { data_id: c.dataIds[0], perfil_id: c.bia.id, resposta: "indisponivel" },
  ]);
  const { data: naData } = await admin.from("escalas")
    .insert({ ministerio_id: c.ministerioId, evento: "Culto na data da consulta", data: diaEm(10), horario: "19:00", situacao: "rascunho" }).select("id").single();
  const { data: foraDaData } = await admin.from("escalas")
    .insert({ ministerio_id: c.ministerioId, evento: "Culto sem consulta", data: diaEm(20), horario: "19:00", situacao: "publicada" }).select("id").single();

  await entrarCom(page, "lider@teste.local");
  await page.goto(`/ministerios/${c.ministerioId}/escalas/${naData!.id}`);
  const nova = page.getByRole("region", { name: "Adicionar vaga" });
  await nova.getByLabel("Função").selectOption({ label: "Vocal" });

  // A escolha da pessoa mostra a resposta de cada uma.
  await expect(nova.getByLabel("Pessoa").locator("option", { hasText: `${c.ana.nome} (disponível)` })).toHaveCount(1);
  await expect(nova.getByLabel("Pessoa").locator("option", { hasText: `${c.bia.nome} (indisponível)` })).toHaveCount(1);

  // Disponível: sem aviso.
  await nova.getByLabel("Pessoa").selectOption({ label: `${c.ana.nome} (disponível)` });
  await nova.getByRole("button", { name: "Adicionar vaga" }).click();
  await expect(page.getByRole("heading", { name: "Vocal" }).first()).toBeVisible();
  await expect(page.getByRole("alert").filter({ hasText: "Atenção" })).toHaveCount(0);

  // Indisponível: aviso, mas o líder pode continuar.
  await nova.getByLabel("Função").selectOption({ label: "Vocal" });
  await nova.getByLabel("Pessoa").selectOption({ label: `${c.bia.nome} (indisponível)` });
  await nova.getByRole("button", { name: "Adicionar vaga" }).click();
  const aviso = page.getByRole("alert").filter({ hasText: "Atenção" });
  await expect(aviso).toContainText("Esta pessoa marcou que está indisponível nesta data.");
  await aviso.getByRole("button", { name: "Continuar mesmo assim" }).click();
  // A indicação permanece ao lado da pessoa escalada.
  await expect(page.getByText("Disponibilidade nesta data:")).toBeVisible();
  await expect(page.getByText("Disponibilidade nesta data:")).toContainText("Indisponível");

  // Data sem consulta: nenhuma indicação nas opções nem nas vagas.
  await page.goto(`/ministerios/${c.ministerioId}/escalas/${foraDaData!.id}`);
  await expect(page.getByText("Disponibilidade nesta data:")).toHaveCount(0);
  await expect(page.getByText("(indisponível)")).toHaveCount(0);

  // Participante comum não vê a indicação na escala da data da consulta (a escala dele só aparece publicada).
  await admin.from("escalas").update({ situacao: "publicada" }).eq("id", naData!.id);
  await page.context().clearCookies();
  await entrarCom(page, c.ana.email);
  await page.goto(`/ministerios/${c.ministerioId}/escalas/${naData!.id}`);
  await expect(page.getByRole("heading", { name: "Culto na data da consulta", level: 1 })).toBeVisible();
  await expect(page.getByText("Disponibilidade nesta data:")).toHaveCount(0);
});
