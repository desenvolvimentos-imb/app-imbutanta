// Campo de formulário acessível: rótulo sempre visível e erro ligado ao campo
// (aria-describedby) para leitores de tela (WCAG AA).
type Props = {
  nome: string;
  rotulo: string;
  tipo?: "text" | "email" | "password";
  erro?: string;
  dica?: string;
  autoComplete?: string;
  defaultValue?: string;
  /** Campos são obrigatórios por padrão; use `false` para campos opcionais. */
  obrigatorio?: boolean;
  maxLength?: number;
};

export function Campo({ nome, rotulo, tipo = "text", erro, dica, autoComplete, defaultValue, obrigatorio = true, maxLength }: Props) {
  const idErro = `${nome}-erro`;
  const idDica = `${nome}-dica`;
  const descricao = [erro ? idErro : null, dica ? idDica : null].filter(Boolean).join(" ") || undefined;

  return (
    <div className="flex flex-col gap-1">
      <label htmlFor={nome} className="text-base font-medium text-slate-900">
        {rotulo}
      </label>
      <input
        id={nome}
        name={nome}
        type={tipo}
        required={obrigatorio}
        maxLength={maxLength}
        autoComplete={autoComplete}
        defaultValue={defaultValue}
        aria-invalid={erro ? true : undefined}
        aria-describedby={descricao}
        className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base text-slate-900 focus:outline-3 focus:outline-offset-2 focus:outline-blue-700"
      />
      {dica && (
        <p id={idDica} className="text-sm text-slate-700">
          {dica}
        </p>
      )}
      {erro && (
        <p id={idErro} className="text-sm font-medium text-red-800">
          {erro}
        </p>
      )}
    </div>
  );
}
