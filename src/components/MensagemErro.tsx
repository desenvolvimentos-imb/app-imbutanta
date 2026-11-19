// Mensagem geral de um formulário. `role="alert"` faz o leitor de tela anunciar o erro.
export function MensagemErro({ texto }: { texto?: string }) {
  if (!texto) return null;
  return (
    <p role="alert" className="rounded-lg border border-red-800 bg-red-50 p-3 text-base text-red-900">
      {texto}
    </p>
  );
}

export function MensagemInfo({ texto }: { texto?: string }) {
  if (!texto) return null;
  return (
    <p role="status" className="rounded-lg border border-blue-900 bg-blue-50 p-3 text-base text-blue-950">
      {texto}
    </p>
  );
}
