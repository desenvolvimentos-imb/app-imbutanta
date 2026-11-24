// T061(b): duas pessoas agindo AO MESMO TEMPO sobre a mesma escala nunca deixam estado misturado
// (SC-004, FR-035). O pgTAP roda numa conexão só e prova a ordem sequencial; aqui são duas sessões
// reais (dois líderes) disparando ao mesmo tempo, contra o Supabase local, várias vezes.
//
// Cenário: o pedido de troca P1 → P3 aguarda a aprovação do líder. No mesmo instante, um líder
// troca a pessoa da vaga (para P2) e o outro líder aprova a troca. Só há dois resultados válidos:
//   A) a troca de pessoa vem primeiro: o pedido perde efeito e a aprovação recebe `conflito_troca`;
//   B) a aprovação vem primeiro (P3 assume) e depois o líder troca P3 por P2: pedido "aprovado".
// Nos dois casos a vaga termina com P2 e ninguém fica com resposta "sobrando".
import { execSync } from "node:child_process";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { beforeAll, describe, expect, it } from "vitest";

const SENHA = "Senha1234";
const RODADAS = 20;

function configLocal() {
  const saida = execSync("npx supabase status -o env", { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
  const pega = (nome: string) => saida.match(new RegExp(`^${nome}="?([^"\\n]+)"?$`, "m"))?.[1] ?? "";
  return { url: pega("API_URL"), anon: pega("ANON_KEY"), servico: pega("SERVICE_ROLE_KEY") };
}

const opcoes = { auth: { persistSession: false, autoRefreshToken: false } };

async function criarPessoa(admin: SupabaseClient, nome: string, email: string) {
  const { data, error } = await admin.auth.admin.createUser({ email, password: SENHA, email_confirm: true, user_metadata: { nome } });
  if (error) throw error;
  await admin.from("perfis").update({ situacao: "aprovado" }).eq("id", data.user.id);
  return data.user.id as string;
}

async function entrar(url: string, anon: string, email: string) {
  const cliente = createClient(url, anon, opcoes);
  const { error } = await cliente.auth.signInWithPassword({ email, password: SENHA });
  if (error) throw error;
  return cliente;
}

function dia(dias: number) {
  const d = new Date(Date.now() + dias * 24 * 60 * 60 * 1000);
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/Sao_Paulo" }).format(d);
}

describe("concorrência: troca de pessoa x aprovação de troca", () => {
  const cfg = configLocal();
  const admin = createClient(cfg.url, cfg.servico, opcoes);
  const sufixo = `${Date.now()}`;
  const ids = {} as { l1: string; l2: string; p1: string; p2: string; p3: string; ministerio: string; funcao: string };
  let clienteL1: SupabaseClient;
  let clienteL2: SupabaseClient;

  beforeAll(async () => {
    const emails = Object.fromEntries(["l1", "l2", "p1", "p2", "p3"].map((k) => [k, `conc-${k}-${sufixo}@teste.local`]));
    for (const k of ["l1", "l2", "p1", "p2", "p3"] as const) {
      ids[k] = await criarPessoa(admin, `Conc ${k} ${sufixo}`, emails[k]);
    }
    const { data: m } = await admin.from("ministerios").insert({ nome: `Teste Concorrência ${sufixo}`, descricao: "" }).select("id").single();
    ids.ministerio = m!.id;
    await admin.from("participacoes_ministerio").insert([
      { ministerio_id: ids.ministerio, perfil_id: ids.l1, papel: "lider" },
      { ministerio_id: ids.ministerio, perfil_id: ids.l2, papel: "lider" },
      ...(["p1", "p2", "p3"] as const).map((k) => ({ ministerio_id: ids.ministerio, perfil_id: ids[k], papel: "participante" })),
    ]);
    const { data: f } = await admin.from("funcoes_ministerio").insert({ ministerio_id: ids.ministerio, nome: "Vocal" }).select("id").single();
    ids.funcao = f!.id;
    await admin.from("aptidoes").insert((["p1", "p2", "p3"] as const).map((k) => ({ funcao_id: ids.funcao, perfil_id: ids[k], tipo: "principal" })));
    clienteL1 = await entrar(cfg.url, cfg.anon, emails.l1);
    clienteL2 = await entrar(cfg.url, cfg.anon, emails.l2);
  });

  it(`em ${RODADAS} rodadas, o estado final é sempre consistente`, async () => {
    const resultados = { troca_primeiro: 0, aprovacao_primeiro: 0 };

    for (let i = 0; i < RODADAS; i++) {
      // Escala nova a cada rodada, com a vaga de P1 e o pedido P1 → P3 aguardando o líder.
      const { data: escala } = await admin.from("escalas")
        .insert({ ministerio_id: ids.ministerio, evento: `Rodada ${i}`, data: dia(5), horario: "19:00", situacao: "publicada" })
        .select("id").single();
      const { data: vaga } = await admin.from("vagas_escala")
        .insert({ escala_id: escala!.id, funcao_id: ids.funcao, perfil_id: ids.p1, ordem: 1 }).select("id").single();
      await admin.from("respostas_escala").insert({ escala_id: escala!.id, perfil_id: ids.p1, resposta: "confirmado", motivo: "" });
      const { data: pedido } = await admin.from("pedidos_troca")
        .insert({ vaga_id: vaga!.id, escala_id: escala!.id, solicitante_id: ids.p1, indicada_id: ids.p3, situacao: "aguardando_lider" })
        .select("id").single();

      // As duas ações disparam ao mesmo tempo, de duas sessões diferentes.
      const [troca, aprovacao] = await Promise.all([
        clienteL1.rpc("salvar_vaga", {
          p_escala: escala!.id, p_vaga: vaga!.id, p_funcao: ids.funcao, p_rotulo: "", p_perfil: ids.p2, p_ciente: true,
        }),
        clienteL2.rpc("decidir_troca_lider", { p_pedido: pedido!.id, p_aprova: true, p_ciente: true }),
      ]);

      // A troca de pessoa nunca falha: só espera a vez.
      expect(troca.error, `rodada ${i}: salvar_vaga`).toBeNull();

      const { data: vagaFinal } = await admin.from("vagas_escala").select("perfil_id").eq("id", vaga!.id).single();
      const { data: pedidoFinal } = await admin.from("pedidos_troca").select("situacao").eq("id", pedido!.id).single();
      const { data: respostas } = await admin.from("respostas_escala").select("perfil_id").eq("escala_id", escala!.id);

      // Em qualquer ordem, a vaga termina com P2 (a troca de pessoa é sempre a última a mexer nela).
      expect(vagaFinal!.perfil_id, `rodada ${i}: vaga`).toBe(ids.p2);
      // Ninguém fica com resposta "sobrando": P1 e P3 deixaram de ocupar vagas na escala.
      expect(respostas, `rodada ${i}: respostas`).toEqual([]);

      if (aprovacao.error) {
        // Resultado A: a troca de pessoa veio primeiro e o pedido perdeu efeito.
        expect(aprovacao.error.message, `rodada ${i}: erro da aprovação`).toBe("conflito_troca");
        expect(pedidoFinal!.situacao, `rodada ${i}: pedido`).toBe("sem_efeito");
        resultados.troca_primeiro++;
      } else {
        // Resultado B: a aprovação veio primeiro e depois o líder trocou a pessoa.
        expect(pedidoFinal!.situacao, `rodada ${i}: pedido`).toBe("aprovado");
        resultados.aprovacao_primeiro++;
      }
    }

    // Registro (não é exigência): quantas vezes cada ordem aconteceu.
    console.info("ordens observadas:", resultados);
    expect(resultados.troca_primeiro + resultados.aprovacao_primeiro).toBe(RODADAS);
  });
});
