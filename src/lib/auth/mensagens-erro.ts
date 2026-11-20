// Traduz erros do Supabase Auth e das funções SQL para mensagens em português
// (RF-007, RF-034). Nunca mostra texto técnico cru e nunca revela se um email existe.

type ErroLike = { code?: string; message?: string; status?: number } | null | undefined;

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
};

export function traduzirErro(erro: ErroLike | Error): string {
  if (!erro) return GENERICA;
  const e = erro as { code?: string; message?: string; status?: number; name?: string };

  if (e.status === 429) return LIMITE;
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
