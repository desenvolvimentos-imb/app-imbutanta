// T033: a pessoa salva a resposta NO MESMO INSTANTE em que o líder fecha a consulta. A consulta é
// travada (`for update`) em toda alteração, então só há duas ordens possíveis e o resultado nunca
// fica misturado (research.md, decisão 5). O pgTAP roda numa conexão só; aqui são duas sessões
// reais (líder e participante), contra o Supabase local, várias vezes.
//   A) a resposta vem primeiro: fica gravada e depois a consulta fecha;
//   B) o fechamento vem primeiro: a resposta é recusada com `consulta_fechada` e nada é gravado.
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

describe("concorrência: responder x fechar a consulta", () => {
  const cfg = configLocal();
  const admin = createClient(cfg.url, cfg.servico, opcoes);
  const sufixo = `${Date.now()}`;
  let ministerio: string;
  let participante: string;
  let clienteLider: SupabaseClient;
  let clientePessoa: SupabaseClient;

  beforeAll(async () => {
    const emailLider = `conc-disp-l-${sufixo}@teste.local`;
    const emailPessoa = `conc-disp-p-${sufixo}@teste.local`;
    const lider = await criarPessoa(admin, `Lider Disp ${sufixo}`, emailLider);
    participante = await criarPessoa(admin, `Pessoa Disp ${sufixo}`, emailPessoa);
    const { data: m } = await admin.from("ministerios").insert({ nome: `Teste Concorrência Disp ${sufixo}`, descricao: "" }).select("id").single();
    ministerio = m!.id;
    await admin.from("participacoes_ministerio").insert([
      { ministerio_id: ministerio, perfil_id: lider, papel: "lider" },
      { ministerio_id: ministerio, perfil_id: participante, papel: "participante" },
    ]);
    clienteLider = await entrar(cfg.url, cfg.anon, emailLider);
    clientePessoa = await entrar(cfg.url, cfg.anon, emailPessoa);
  });

  it(`em ${RODADAS} rodadas, o resultado é sempre uma das duas ordens, nunca misto`, async () => {
    const resultados = { resposta_primeiro: 0, fechamento_primeiro: 0 };

    for (let i = 0; i < RODADAS; i++) {
      const { data: consulta } = await admin.from("consultas_disponibilidade")
        .insert({ ministerio_id: ministerio, titulo: `Rodada ${i}` }).select("id").single();
      const { data: data } = await admin.from("datas_consulta")
        .insert({ consulta_id: consulta!.id, ministerio_id: ministerio, data: dia(30 + i) }).select("id").single();

      const [resposta, fechamento] = await Promise.all([
        clientePessoa.rpc("responder_disponibilidade", {
          p_consulta: consulta!.id,
          p_respostas: [{ data_id: data!.id, resposta: "disponivel" }],
          p_observacao: null,
        }),
        clienteLider.rpc("fechar_consulta", { p_consulta: consulta!.id }),
      ]);

      expect(fechamento.error, "o fechamento nunca falha").toBeNull();
      const { data: linhas } = await admin.from("respostas_disponibilidade").select("resposta").eq("data_id", data!.id).eq("perfil_id", participante);
      const { data: depois } = await admin.from("consultas_disponibilidade").select("fechada").eq("id", consulta!.id).single();
      expect(depois!.fechada).toBe(true);

      if (resposta.error === null) {
        expect(linhas, "resposta aceita fica gravada").toHaveLength(1);
        resultados.resposta_primeiro++;
      } else {
        expect(resposta.error.message).toBe("consulta_fechada");
        expect(linhas, "resposta recusada não deixa nada gravado").toHaveLength(0);
        resultados.fechamento_primeiro++;
      }
    }
    // Só para registro: mostra que as duas ordens podem acontecer.
    console.info("[concorrência disponibilidade]", resultados);
  });
});
