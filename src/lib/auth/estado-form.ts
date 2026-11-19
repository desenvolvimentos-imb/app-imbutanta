// Estado devolvido pelas Server Actions de formulário (usado com useActionState).
export type EstadoForm = {
  /** Mensagem geral de erro (aparece no topo do formulário). */
  erro?: string;
  /** Erros por campo, pelo atributo `name` do campo. */
  erros?: Record<string, string>;
  /** Mensagem de sucesso/orientação. */
  info?: string;
  /** Valores digitados, para não apagar o formulário em caso de erro (nunca a senha). */
  valores?: Record<string, string>;
};
