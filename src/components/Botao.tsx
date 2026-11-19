"use client";
// Botões com alvo de toque grande (≥ 44 px, WCAG). BotaoEnviar desativa enquanto envia,
// evitando cliques duplos (ex.: cadastro criado duas vezes).
import { useFormStatus } from "react-dom";
import type { ButtonHTMLAttributes } from "react";

type Variante = "primario" | "secundario" | "perigo";

const ESTILOS: Record<Variante, string> = {
  primario: "bg-blue-900 text-white hover:bg-blue-800",
  secundario: "border border-slate-500 bg-white text-slate-900 hover:bg-slate-100",
  perigo: "bg-red-800 text-white hover:bg-red-700",
};

export const classesBotao = (variante: Variante = "primario") =>
  `inline-flex min-h-12 w-full items-center justify-center rounded-lg px-4 text-base font-semibold focus:outline-3 focus:outline-offset-2 focus:outline-blue-700 disabled:opacity-60 ${ESTILOS[variante]}`;

type Props = ButtonHTMLAttributes<HTMLButtonElement> & { variante?: Variante };

export function BotaoEnviar({ variante = "primario", children, ...resto }: Props) {
  const { pending } = useFormStatus();
  return (
    <button type="submit" disabled={pending} className={classesBotao(variante)} {...resto}>
      {pending ? "Aguarde..." : children}
    </button>
  );
}
