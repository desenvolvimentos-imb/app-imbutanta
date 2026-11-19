// O parâmetro `voltar` (página que a pessoa tentava abrir antes do login) só pode apontar
// para caminhos internos. Aceitar qualquer endereço permitiria "open redirect": levar a
// pessoa, logo após o login, a um site falso.

// Rotas de autenticação: voltar para elas criaria um laço.
const ROTAS_BLOQUEADAS = ["/entrar", "/cadastrar", "/auth", "/recuperar-senha", "/redefinir-senha"];

export function caminhoVoltarSeguro(valor: string | null | undefined, padrao = "/inicio"): string {
  if (!valor) return padrao;
  // Deve começar com "/" mas não "//" (endereço relativo ao protocolo) nem "/\".
  if (!valor.startsWith("/") || valor.startsWith("//") || valor.startsWith("/\\")) return padrao;
  // Sem barra invertida nem caracteres de controle (evita injeção de cabeçalho).
  if (/[\\\u0000-\u001f\u007f]/.test(valor)) return padrao;

  const caminho = valor.split(/[?#]/)[0];
  if (ROTAS_BLOQUEADAS.some((r) => caminho === r || caminho.startsWith(`${r}/`))) return padrao;
  return valor;
}
