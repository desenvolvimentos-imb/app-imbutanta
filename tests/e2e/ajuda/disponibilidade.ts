// Ajuda para os testes da disponibilidade (004): cria pessoas, ministério e consulta pelo cliente
// administrativo do Supabase LOCAL, sem passar pela interface.
import { clienteAdmin } from "./admin";
import { emailNovo, SENHA } from "./email";

export const ID_LUCAS = "11111111-1111-1111-1111-111111111102"; // lider@teste.local (seed)

/** Data de hoje + N dias em São Paulo, "AAAA-MM-DD". */
export function diaEm(dias: number) {
  const d = new Date(Date.now() + dias * 24 * 60 * 60 * 1000);
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/Sao_Paulo" }).format(d);
}

export async function criarPessoa(prefixo: string, sufixo: string) {
  const admin = clienteAdmin();
  const nome = `${prefixo} ${sufixo}`;
  const email = emailNovo(prefixo.toLowerCase());
  const { data, error } = await admin.auth.admin.createUser({ email, password: SENHA, email_confirm: true, user_metadata: { nome } });
  if (error) throw error;
  await admin.from("perfis").update({ situacao: "aprovado" }).eq("id", data.user.id);
  return { id: data.user.id as string, nome, email };
}

/**
 * Ministério com o Lucas (lider@teste.local) como líder e duas participantes; opcionalmente uma
 * consulta aberta com as datas informadas.
 */
export async function prepararMinisterio(opcoes: { datas?: { dias: number; rotulo?: string }[]; titulo?: string } = {}) {
  const admin = clienteAdmin();
  const sufixo = `${Date.now()}${Math.floor(Math.random() * 100)}`;
  const { data: m } = await admin.from("ministerios").insert({ nome: `Teste Disp ${sufixo}`, descricao: "" }).select("id").single();
  if (!m) throw new Error("ministério não criado");
  const [ana, bia] = await Promise.all([criarPessoa("Ana", sufixo), criarPessoa("Bia", sufixo)]);
  await admin.from("participacoes_ministerio").insert([
    { ministerio_id: m.id, perfil_id: ID_LUCAS, papel: "lider" },
    { ministerio_id: m.id, perfil_id: ana.id, papel: "participante" },
    { ministerio_id: m.id, perfil_id: bia.id, papel: "participante" },
  ]);
  let consultaId: string | null = null;
  let dataIds: string[] = [];
  const titulo = opcoes.titulo ?? `Consulta ${sufixo}`;
  if (opcoes.datas) {
    const { data: c } = await admin.from("consultas_disponibilidade")
      .insert({ ministerio_id: m.id, titulo, mensagem: "Marquem suas datas." }).select("id").single();
    consultaId = c!.id;
    const { data: ds } = await admin.from("datas_consulta")
      .insert(opcoes.datas.map((d) => ({ consulta_id: consultaId, ministerio_id: m.id, data: diaEm(d.dias), rotulo: d.rotulo ?? "" })))
      .select("id, data").order("data");
    dataIds = (ds ?? []).map((d) => d.id as string);
  }
  return { ministerioId: m.id as string, ana, bia, consultaId, dataIds, titulo, sufixo };
}
