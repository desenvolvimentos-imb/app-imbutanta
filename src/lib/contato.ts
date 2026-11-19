// Contato para pedidos sobre dados pessoais (LGPD), mostrado nas páginas públicas.
// Vem da variável de ambiente EMAIL_CONTATO (configurada na Vercel), e não do código,
// para o email não ficar no repositório público. Sem a variável, as páginas orientam a
// procurar a liderança da igreja.
export function emailDeContato(): string | undefined {
  const email = process.env.EMAIL_CONTATO?.trim();
  return email ? email : undefined;
}
