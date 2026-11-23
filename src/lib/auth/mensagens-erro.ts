// Traduz erros do Supabase Auth e das funções SQL para mensagens em português
// (RF-007, RF-034). Nunca mostra texto técnico cru e nunca revela se um email existe.

type ErroLike = { code?: string; message?: string; status?: number; details?: string } | null | undefined;

const GENERICA = "Algo deu errado. Tente de novo em instantes.";
const SEM_CONEXAO = "Sem conexão. Verifique a internet e tente de novo.";
const LIMITE = "Muitas tentativas. Aguarde alguns minutos e tente de novo.";

// Códigos do Supabase Auth (campo `code`) e das nossas funções SQL (message = código).
const POR_CODIGO: Record<string, string> = {
  invalid_credentials: "Email ou senha incorretos.",
  email_not_confirmed: "Confirme o seu email antes de entrar. Enviamos um link para você.",
  user_already_exists:
    "Não foi possível criar a conta com esses dados. Tente entrar ou recuperar a senha.",
  email_exists:
    "Não foi possível criar a conta com esses dados. Tente entrar ou recuperar a senha.",
  weak_password: "A senha é fraca. Use pelo menos 8 caracteres, com letras e números.",
  same_password: "A nova senha precisa ser diferente da atual.",
  over_request_rate_limit: LIMITE,
  over_email_send_rate_limit: "Muitos emails enviados. Aguarde alguns minutos e tente de novo.",
  otp_expired: "Este link expirou ou já foi usado. Peça um novo.",
  flow_state_expired: "Este link expirou ou já foi usado. Peça um novo.",
  flow_state_not_found: "Este link expirou ou já foi usado. Peça um novo.",
  sem_permissao: "Você não tem permissão para esta ação.",
  conflito_situacao: "A situação desta pessoa mudou. Atualize a lista.",
  transicao_invalida: "Esta alteração não é permitida.",
  ultimo_administrador:
    "Não é possível deixar o app sem administrador. Passe o papel de administrador a outra pessoa antes.",
  nao_encontrado: "Pessoa não encontrada.",
  // Ministérios (funcionalidade 002)
  nome_duplicado: "Já existe um ministério ativo com esse nome.",
  nome_invalido: "Informe um nome de 2 a 60 caracteres e uma descrição de até 200.",
  ultimo_lider: "O ministério precisa de pelo menos um líder. Defina outro líder antes.",
  ministerio_inativo: "Este ministério está desativado.",
  ja_participa: "Esta pessoa já participa deste ministério.",
  pedido_duplicado: "Você já tem um pedido pendente para este ministério.",
  conflito_pedido: "Este pedido já foi decidido. Atualize a lista.",
  pessoa_invalida: "Esta pessoa não pode ser adicionada.",
  sem_lider: "Escolha um líder para reativar o ministério.",
  // Escalas (funcionalidade 003)
  funcao_duplicada: "Já existe uma função ativa com esse nome neste ministério.",
  funcao_invalida: "Escolha uma função ativa deste ministério.",
  evento_invalido: "Informe o nome do evento (2 a 80 caracteres).",
  data_passada: "A data não pode ser anterior a hoje.",
  escala_somente_leitura: "Esta escala já passou e não pode mais ser alterada.",
  escala_cancelada: "Esta escala foi cancelada.",
  escala_sem_vagas: "Adicione ao menos uma vaga antes de publicar.",
  escala_nao_publicada: "Esta escala ainda não foi publicada.",
  limite_vagas: "Uma escala pode ter no máximo 50 vagas.",
  nao_participante: "Só participantes do ministério podem ser escalados.",
  evento_iniciado: "O horário de início deste evento já passou.",
  nao_escalado: "Você não está escalado nesta escala.",
  ja_escalada: "Esta pessoa já está escalada nesta escala.",
  troca_duplicada: "Esta vaga já tem um pedido de troca em andamento.",
  conflito_troca: "Este pedido já foi decidido ou perdeu efeito. Atualize a lista.",
  troca_invalida: "Escolha outra pessoa do ministério que ainda não esteja nesta escala.",
};

export function traduzirErro(erro: ErroLike | Error): string {
  if (!erro) return GENERICA;
  const e = erro as { code?: string; message?: string; status?: number; name?: string; details?: string };

  if (e.status === 429) return LIMITE;
  // O banco informa em `details` o nome do ministério que ficaria sem líder: citar na mensagem.
  if (e.message === "ultimo_lider" && e.details) {
    return `O ministério ${e.details} precisa de pelo menos um líder. Defina outro líder antes.`;
  }
  if (e.code && POR_CODIGO[e.code]) return POR_CODIGO[e.code];
  // Funções SQL levantam exceção com message igual ao código.
  if (e.message && POR_CODIGO[e.message]) return POR_CODIGO[e.message];

  const texto = `${e.name ?? ""} ${e.message ?? ""}`.toLowerCase();
  if (texto.includes("fetch failed") || texto.includes("failed to fetch") || texto.includes("network")) {
    return SEM_CONEXAO;
  }
  // Sem tradução: a tela mostra só a mensagem genérica, e o motivo real vai para o log do
  // servidor (Vercel), onde a pessoa que mantém o app consegue diagnosticar (ex.: SMTP recusado).
  // Emails são ocultados: o log não pode guardar dados pessoais (constitution V).
  console.error("[auth] erro sem tradução", {
    code: e.code,
    status: e.status,
    name: e.name,
    message: e.message?.replace(/[^\s"'<>]+@[^\s"'<>]+/g, "[email]"),
  });
  return GENERICA;
}
